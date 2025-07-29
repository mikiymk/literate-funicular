# サンプル用の言語

## 表記方法

```bnf
定義 ::= 記号 | 記号 | 記号

定義の間は1行以上空ける ::= 記号 | 記号 | 記号

繰り返し ::= {0〜回}* | {1〜回}+ | {0〜1回}?
```

## 1. Simple-Calculator

四則演算、累乗と括弧のみの計算式。

```ebnf
Expr ::= AddExpr

AddExpr ::= MulExpr
          | AddExpr "+" MulExpr
          | AddExpr "-" MulExpr

MulExpr ::= PowExpr
          | MulExpr "*" PowExpr
          | MulExpr "/" PowExpr

PowExpr ::= Prim
          | Prim "^" PowExpr

Prim ::= number
       | "(" Expr ")"
```

### 優先順位表

`左の記号 op 上の記号`のopの部分。

|      | id  | +, - | *, / | ^   | (   | )   | $   |
| ---- | --- | ---- | ---- | --- | --- | --- | --- |
| id   |     | ⋗    | ⋗    | ⋗   |     | ⋗   | ⋗   |
| +, - | ⋖   | ⋗    | ⋖    | ⋖   | ⋖   | ⋗   | ⋗   |
| *, / | ⋖   | ⋗    | ⋗    | ⋖   | ⋖   | ⋗   | ⋗   |
| ^    | ⋖   | ⋗    | ⋗    | ⋖   | ⋖   | ⋗   | ⋗   |
| (    | ⋖   | ⋖    | ⋖    | ⋖   | ⋖   | ≐   |     |
| )    |     | ⋗    | ⋗    | ⋗   |     | ⋗   | ⋗   |
| $    | ⋖   | ⋖    | ⋖    | ⋖   | ⋖   |     | A   |

## 2. Subset-C

C言語をベースにして、機能を制限した。
空白、改行は無視する。

参考: [The syntax of C in Backus-Naur Form](https://cs.wmich.edu/~gupta/teaching/cs4850/sumII06/The%20syntax%20of%20C%20in%20Backus-Naur%20form.htm)

```bnf
<translation-unit> ::= {<function-definition>}*

<function-definition> ::= int <identifier> ( <parameter-list> ) <compound-statement>

<parameter-list> ::= <parameter-declaration>
                   | <parameter-list> , <parameter-declaration>

<parameter-declaration> ::= int <identifier>

<declaration> ::=  int <identifier> ;

<statement> ::= <expression> ;
              | <compound-statement>
              | if ( <expression> ) <compound-statement> else <compound-statement>
              | while ( <expression> ) <compound-statement>
              | return {<expression>}? ;

<compound-statement> ::= { {<declaration>}* {<statement>}* }

<expression> ::= <assignment-expression>

<assignment-expression> ::= <equality-expression>
                          | <unary-expression> = <assignment-expression>

<equality-expression> ::= <relational-expression>
                        | <equality-expression> == <relational-expression>

<relational-expression> ::= <additive-expression>
                          | <relational-expression> < <additive-expression>
                          | <relational-expression> > <additive-expression>

<additive-expression> ::= <multiplicative-expression>
                        | <additive-expression> + <multiplicative-expression>
                        | <additive-expression> - <multiplicative-expression>

<multiplicative-expression> ::= <unary-expression>
                              | <multiplicative-expression> * <unary-expression>
                              | <multiplicative-expression> / <unary-expression>
                              | <multiplicative-expression> % <unary-expression>

<unary-expression> ::= <primary-expression>
                     | - <primary-expression>

<primary-expression> ::= <identifier>
                       | <constant>
                       | ( <expression> )
```

## 3. Subset-Json

JSONをベースにして、機能を制限した。
空白、改行は無視する。

```bnf
<json> ::= <value>

<value> ::= <object>
          | <array>
          | <string>
          | <integer>

<object> ::= { {<members>}? }

<members> ::= <member>
            | <member> , <members>

<member> ::= <string> : <value>

<array> ::= [ {<elements>}? ]

<elements> ::= <value>
             | <value> , <elements>
```
