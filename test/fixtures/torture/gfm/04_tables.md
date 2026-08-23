# Tables

Basic table:

| Column A | Column B | Column C |
|----------|----------|----------|
| a1       | b1       | c1       |
| a2       | b2       | c2       |

Alignment:

| Left | Center | Right |
|:-----|:------:|------:|
| l    |   c    |     r |
| ll   |   cc   |    rr |

Formatting inside cells:

| Feature | Example | Notes |
|---|---|---|
| emphasis | *italic* and **bold** | both |
| code | `inline()` | backticks |
| link | [example](https://example.com) | external |
| strike | ~~gone~~ | GFM |
| pipe | a \| b | escaped pipe |

Ragged rows — fewer and more cells than the header:

| One | Two | Three |
|---|---|---|
| only one |
| a | b | c | d | e |

Empty cells:

| A | B |
|---|---|
|   | b |
| a |   |
|   |   |

A wide table that must scroll horizontally rather than squash:

| id | name | email | department | manager | location | started | title | level | status | notes |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Nguyễn Văn A | a@example.com | Engineering | B | Hà Nội | 2024-01-15 | Software Engineer | L3 | active | a reasonably long note that pushes the width |
| 2 | 田中太郎 | tanaka@example.com | Design | C | 東京 | 2023-06-01 | Product Designer | L4 | active | another long note to keep the column wide |

A table immediately followed by a paragraph with no blank line:
| X | Y |
|---|---|
| 1 | 2 |
This paragraph directly follows the table.
