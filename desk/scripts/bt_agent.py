#!/usr/bin/env python3
"""desk'in Bluetooth eşleşme yardımcısı (BlueZ "agent").

Bir cihazla eşleşirken BlueZ onay, PIN ya da kod isteyebilir; isteyecek bir yardımcı yoksa eşleşme
hiç olmaz ya da anahtar saklanmadan yarım kalır (plan: Sorun 52, 79). Bu betik o yardımcı olarak
kaydolur ve her isteği desk'e sorar. desk (services/BluetoothStatus.qml) bunu başlatır ve
stdin/stdout'tan JSON satırlarıyla konuşur:

  desk'e: {"id": 3, "kind": "confirm", "device": "/org/bluez/hci0/dev_…", "name": "…", "address": "…",
           "code": "033412"}
          kind:  confirm      kodu onayla (iki cihazda aynı kod)          → yanıt: ok
                 authorize    cihaz eşleşmek istiyor                       → yanıt: ok
                 service      eşleşmemiş cihaz bir servise bağlanmak istiyor → yanıt: ok
                 pin          PIN yazılacak (eski cihazlar; çoğu 0000)      → yanıt: ok + value
                 passkey      öbür cihazın gösterdiği 6 haneli kod yazılacak → yanıt: ok + value
                 show-pin     şu PIN'i cihazda (klavyede) yaz              → yanıt yok
                 show-passkey şu kodu cihazda yaz; "entered" yazılan hane    → yanıt yok
                 cancel       BlueZ vazgeçti (süre doldu, cihaz gitti): bekleyenler kapanır
                 ready / error
  desk'ten: {"id": 3, "ok": true, "value": "0000"}

Yanıt gelmezse BlueZ bir dakika içinde vazgeçer. stdin kapanınca (desk kapandı ya da yeniden yüklendi)
yardımcı kaydını siler ve çıkar. bluetoothd yeniden başlarsa yeniden kaydolur.

Gerekenler: Python ve dbus-next (desk/nix/home.nix, DESK_PYTHON). Denemek için sistem D-Bus'ı yerine
başka bir D-Bus: DESK_BT_BUS=unix:path=… (orada sahte bir org.bluez olmalı).
"""

import asyncio
import json
import os
import sys

from dbus_next import BusType, DBusError, Message, MessageType
from dbus_next.aio import MessageBus
from dbus_next.service import ServiceInterface, method

AGENT_PATH = "/desk/agent"
CAPABILITY = "KeyboardDisplay"   # kod gösterebilir, onay ve yazı alabilir
ANSWER_TIMEOUT = 90              # BlueZ daha önce vazgeçer; burası yalnızca güvence
REJECTED = "org.bluez.Error.Rejected"
CANCELED = "org.bluez.Error.Canceled"


def send(payload):
    sys.stdout.write(json.dumps(payload, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def unwrap(value):
    return getattr(value, "value", value)


class Agent(ServiceInterface):
    def __init__(self, bus):
        super().__init__("org.bluez.Agent1")
        self.bus = bus
        self.pending = {}
        self.next_id = 1

    # ---------- desk'e sor ----------
    async def device_info(self, device):
        reply = await self.bus.call(Message(
            destination="org.bluez", path=device, interface="org.freedesktop.DBus.Properties",
            member="GetAll", signature="s", body=["org.bluez.Device1"]))
        props = reply.body[0] if reply.message_type == MessageType.METHOD_RETURN else {}
        get = lambda key, default: unwrap(props.get(key, default))
        address = get("Address", "")
        return {
            "name": get("Alias", "") or get("Name", "") or address,
            "address": address,
            "trusted": bool(get("Trusted", False)),
            "bonded": bool(get("Bonded", False)) or bool(get("Paired", False)),
        }

    async def ask(self, kind, device, **extra):
        info = await self.device_info(device)
        request_id = self.next_id
        self.next_id += 1
        future = asyncio.get_running_loop().create_future()
        self.pending[request_id] = future
        send(dict(id=request_id, kind=kind, device=device, name=info["name"], address=info["address"], **extra))
        try:
            answer = await asyncio.wait_for(future, ANSWER_TIMEOUT)
        except asyncio.TimeoutError:
            raise DBusError(CANCELED, "Yanıt gelmedi")
        finally:
            self.pending.pop(request_id, None)
        if not answer.get("ok"):
            raise DBusError(REJECTED, "Reddedildi")
        return answer

    async def tell(self, kind, device, **extra):
        info = await self.device_info(device)
        send(dict(id=0, kind=kind, device=device, name=info["name"], address=info["address"], **extra))

    def answered(self, answer):
        future = self.pending.get(answer.get("id"))
        if future and not future.done():
            future.set_result(answer)

    def cancel_all(self):
        for future in self.pending.values():
            if not future.done():
                future.set_result({"ok": False})

    # ---------- org.bluez.Agent1 ----------
    @method()
    def Release(self):
        pass

    @method()
    async def RequestPinCode(self, device: "o") -> "s":
        answer = await self.ask("pin", device)
        pin = str(answer.get("value", "")).strip()
        if not 1 <= len(pin) <= 16:
            raise DBusError(REJECTED, "PIN 1–16 karakter olmalı")
        return pin

    @method()
    async def DisplayPinCode(self, device: "o", pincode: "s"):
        await self.tell("show-pin", device, code=pincode)

    @method()
    async def RequestPasskey(self, device: "o") -> "u":
        answer = await self.ask("passkey", device)
        value = str(answer.get("value", "")).strip()
        if not value.isdigit() or int(value) > 999999:
            raise DBusError(REJECTED, "Kod 6 haneli bir sayı olmalı")
        return int(value)

    @method()
    async def DisplayPasskey(self, device: "o", passkey: "u", entered: "q"):
        await self.tell("show-passkey", device, code=f"{passkey:06d}", entered=entered)

    @method()
    async def RequestConfirmation(self, device: "o", passkey: "u"):
        await self.ask("confirm", device, code=f"{passkey:06d}")

    @method()
    async def RequestAuthorization(self, device: "o"):
        await self.ask("authorize", device)

    @method()
    async def AuthorizeService(self, device: "o", uuid: "s"):
        # Eşleşmiş ya da güvenilir cihazın servislerine sormadan izin ver
        info = await self.device_info(device)
        if info["trusted"] or info["bonded"]:
            return
        await self.ask("service", device, uuid=uuid)

    @method()
    def Cancel(self):
        self.cancel_all()
        send({"id": 0, "kind": "cancel"})


async def call(bus, interface, member, signature="", body=()):
    reply = await bus.call(Message(destination="org.bluez", path="/org/bluez", interface=interface,
                                   member=member, signature=signature, body=list(body)))
    if reply.message_type == MessageType.ERROR:
        raise DBusError(reply.error_name, (reply.body or [""])[0])


async def register(bus):
    await call(bus, "org.bluez.AgentManager1", "RegisterAgent", "os", [AGENT_PATH, CAPABILITY])
    await call(bus, "org.bluez.AgentManager1", "RequestDefaultAgent", "o", [AGENT_PATH])


async def keep_registered(bus):
    """bluetoothd yoksa bekler; yeniden başlarsa yeniden kaydolur."""
    wake = asyncio.Event()

    def on_message(msg):
        if (msg.message_type == MessageType.SIGNAL and msg.member == "NameOwnerChanged"
                and msg.body and msg.body[0] == "org.bluez"):
            wake.set()

    bus.add_message_handler(on_message)
    await bus.call(Message(destination="org.freedesktop.DBus", path="/org/freedesktop/DBus",
                           interface="org.freedesktop.DBus", member="AddMatch", signature="s",
                           body=["type='signal',interface='org.freedesktop.DBus',member='NameOwnerChanged',"
                                 "arg0='org.bluez'"]))
    registered, last_error = False, None
    while True:
        wake.clear()
        try:
            await register(bus)
            if not registered:
                send({"id": 0, "kind": "ready"})
            registered, last_error = True, None
        except DBusError as error:
            if error.type == "org.bluez.Error.AlreadyExists":
                registered = True
            else:
                registered = False
                message = f"{error.type}: {error.text}"
                if message != last_error:   # bluetoothd yokken her denemede yazma
                    send({"id": 0, "kind": "error", "message": message})
                last_error = message
        try:
            await asyncio.wait_for(wake.wait(), None if registered else 10)
        except asyncio.TimeoutError:
            pass


async def read_answers(agent):
    loop = asyncio.get_running_loop()
    reader = asyncio.StreamReader()
    await loop.connect_read_pipe(lambda: asyncio.StreamReaderProtocol(reader), sys.stdin)
    while line := await reader.readline():
        try:
            agent.answered(json.loads(line))
        except (ValueError, AttributeError):
            print(f"anlaşılmayan satır: {line!r}", file=sys.stderr)


def quiet_rejections(loop, context):
    # dbus-next 0.2.3, async bir yöntemin hatasını (Rejected) yanıt olarak gönderdikten sonra bir de
    # "Exception in callback" diye yazıyor; yanıt doğru gidiyor, yalnızca gürültü.
    if isinstance(context.get("exception"), DBusError):
        return
    loop.default_exception_handler(context)


async def main():
    asyncio.get_running_loop().set_exception_handler(quiet_rejections)
    address = os.environ.get("DESK_BT_BUS")
    bus = await (MessageBus(bus_address=address) if address else MessageBus(bus_type=BusType.SYSTEM)).connect()
    agent = Agent(bus)
    bus.export(AGENT_PATH, agent)
    watcher = asyncio.create_task(keep_registered(bus))
    try:
        await read_answers(agent)   # desk kapanınca biter
    finally:
        watcher.cancel()
        agent.cancel_all()
        try:
            await call(bus, "org.bluez.AgentManager1", "UnregisterAgent", "o", [AGENT_PATH])
        except Exception:
            pass
        bus.disconnect()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
