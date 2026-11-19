pragma Singleton

import QtQuick
import Quickshell

// Aramadaki hesap makinesi. Yazılan işlemi kendi ayrıştırıcısıyla hesaplar (eval kullanılmaz).
//
//   + - * / ^ ( )      ×, ÷ ve "mod" de olur; 2(3+1) ve 2pi gibi yan yana yazım çarpmadır
//   5!                 faktöriyel
//   15%                yüzde (0,15); "15% of 80" ya da "80'in %15'i" de olur
//   sqrt kök sin cos tan asin acos atan ln log exp abs floor ceil round
//   pi π e
// Ondalık ayırıcı virgül ya da nokta olabilir (2,5 = 2.5). Açılar radyan.
Singleton {
    id: root

    // Hesap gibi görünüyor mu: en az bir rakam ve bir işlem ya da fonksiyon.
    // Tek başına bir sayı (bir uygulama adı ya da yıl gibi) hesap sayılmaz.
    function looksLikeMath(text) {
        const t = text.trim().toLowerCase();
        if (t.startsWith("="))
            return true;
        if (!/[0-9πe]/.test(t))
            return false;
        // Fonksiyon ve sabit adları rakama bitişik de olabilir ("2pi"); harfe bitişikse sayılmaz ("pilot")
        return /[-+*/^×÷%!()]|(^|[^a-zçğıöşü])(sqrt|kök|sin|cos|tan|asin|acos|atan|ln|log|exp|abs|floor|ceil|round|pi|π|mod|of)(?![a-zçğıöşü])|'in|'ın|'un|'ün/.test(t);
    }

    // Sonuç sayı ya da null (hesaplanamadıysa)
    function evaluate(text) {
        let t = text.trim().toLowerCase();
        if (t.startsWith("="))
            t = t.slice(1);
        // "80'in %15'i" → "15% of 80"
        t = t.replace(/^\s*([\d.,]+)\s*'?(in|ın|un|ün|nin|nın|nun|nün)\s*%\s*([\d.,]+)\s*'?(i|ı|u|ü|si|sı|su|sü)?\s*$/, "$3% of $1");
        try {
            const p = parser(t);
            const value = p.expression();
            if (p.peek() !== null)
                return null;
            return isFinite(value) ? value : null;
        } catch (e) {
            return null;
        }
    }

    // Türkçe biçim: virgül ondalık, en çok 10 anlamlı basamak ("1,4142135624")
    function format(value) {
        if (Math.abs(value) >= 1e15 || (value !== 0 && Math.abs(value) < 1e-9))
            return value.toExponential(8).replace(/\.?0+e/, "e").replace(".", ",");
        const rounded = parseFloat(value.toPrecision(12));
        return String(rounded).replace(".", ",");
    }

    // --- Ayrıştırıcı (özyinelemeli iniş)
    function tokenize(t) {
        const tokens = [];
        let i = 0;
        while (i < t.length) {
            const ch = t[i];
            if (/\s/.test(ch)) {
                i++;
                continue;
            }
            // 2,5 ya da 2.5; bilimsel yazım da olur (1e5, 2.5e-3)
            const number = t.slice(i).match(/^\d+(?:[.,]\d+)?(?:e[+-]?\d+)?/);
            if (number) {
                tokens.push({
                    type: "num",
                    value: parseFloat(number[0].replace(",", "."))
                });
                i += number[0].length;
                continue;
            }
            const word = t.slice(i).match(/^[a-zçğıöşüπ]+/);
            if (word) {
                tokens.push({
                    type: "id",
                    value: word[0]
                });
                i += word[0].length;
                continue;
            }
            const op = {
                "×": "*",
                "÷": "/",
                "−": "-"
            }[ch] ?? ch;
            if (!"+-*/^()%!".includes(op))
                throw "beklenmeyen: " + ch;
            tokens.push({
                type: "op",
                value: op
            });
            i++;
        }
        return tokens;
    }

    readonly property var functions: ({
            "sqrt": Math.sqrt,
            "kök": Math.sqrt,
            "sin": Math.sin,
            "cos": Math.cos,
            "tan": Math.tan,
            "asin": Math.asin,
            "acos": Math.acos,
            "atan": Math.atan,
            "ln": Math.log,
            "log": Math.log10,
            "exp": Math.exp,
            "abs": Math.abs,
            "floor": Math.floor,
            "ceil": Math.ceil,
            "round": Math.round
        })
    readonly property var constants: ({
            "pi": Math.PI,
            "π": Math.PI,
            "e": Math.E
        })

    function factorial(n) {
        if (n < 0 || n !== Math.floor(n) || n > 170)
            throw "faktöriyel";
        let r = 1;
        for (let k = 2; k <= n; k++)
            r *= k;
        return r;
    }

    function parser(text) {
        const tokens = tokenize(text);
        let pos = 0;
        const fns = root.functions;
        const consts = root.constants;

        const p = {
            peek: () => tokens[pos] ?? null,
            next: () => tokens[pos++],
            isOp: v => (tokens[pos]?.type === "op" && tokens[pos].value === v),
            isWord: v => (tokens[pos]?.type === "id" && tokens[pos].value === v),
            // Yan yana yazım çarpma mı: 2pi, 2(3), (1)(2), 2sqrt(4)
            startsFactor: () => {
                const t = tokens[pos];
                return t !== undefined && (t.type === "num" || (t.type === "id" && t.value !== "mod" && t.value !== "of") || (t.type === "op" && t.value === "("));
            }
        };

        p.expression = () => {
            let value = p.term();
            while (p.isOp("+") || p.isOp("-")) {
                const op = p.next().value;
                const right = p.term();
                value = op === "+" ? value + right : value - right;
            }
            return value;
        };
        p.term = () => {
            let value = p.unary();
            for (;;) {
                if (p.isOp("*") || p.isOp("/")) {
                    const op = p.next().value;
                    const right = p.unary();
                    value = op === "*" ? value * right : value / right;
                } else if (p.isWord("mod")) {
                    p.next();
                    value = value % p.unary();
                } else if (p.isWord("of")) {
                    // "15% of 80": soldaki zaten 0,15
                    p.next();
                    value = value * p.unary();
                } else if (p.startsFactor()) {
                    value = value * p.power();
                } else {
                    return value;
                }
            }
        };
        // Eksi işareti üs almadan sonra gelir: -3^2 = -(3^2) = -9; 2^-1 = 0,5
        p.unary = () => {
            if (p.isOp("-")) {
                p.next();
                return -p.unary();
            }
            if (p.isOp("+")) {
                p.next();
                return p.unary();
            }
            return p.power();
        };
        p.power = () => {
            const base = p.postfix();
            if (p.isOp("^")) {
                p.next();
                return Math.pow(base, p.unary()); // sağdan birleşir: 2^3^2 = 2^9
            }
            return base;
        };
        p.postfix = () => {
            let value = p.primary();
            for (;;) {
                if (p.isOp("!")) {
                    p.next();
                    value = root.factorial(value);
                } else if (p.isOp("%")) {
                    p.next();
                    value = value / 100;
                } else {
                    return value;
                }
            }
        };
        p.primary = () => {
            const t = p.next();
            if (!t)
                throw "eksik";
            if (t.type === "num")
                return t.value;
            if (t.type === "op" && t.value === "(") {
                const value = p.expression();
                if (!p.isOp(")"))
                    throw ") eksik";
                p.next();
                return value;
            }
            if (t.type === "op" && t.value === "%") {
                // "%15" (Türkçe yazım): 0,15
                return p.postfix() / 100;
            }
            if (t.type === "id") {
                if (t.value in consts)
                    return consts[t.value];
                if (t.value in fns) {
                    // sqrt(2) ya da sqrt 2
                    return fns[t.value](p.power());
                }
            }
            throw "bilinmeyen: " + t.value;
        };
        return p;
    }
}
