# Lists and task lists

Tight unordered list:

- one
- two
- three

Loose unordered list:

- one

- two

- three

Ordered list starting at 1:

1. first
2. second
3. third

Ordered list starting elsewhere:

7. seven
8. eight
9. nine

Mixed nesting:

- level 1
  - level 2
    - level 3
      1. ordered inside unordered
      2. second
         - back to unordered
- level 1 again

Task lists, which must render as inert checkboxes (docs/04):

- [ ] unchecked
- [x] checked
- [X] checked, capital X
- [ ] task with **formatting** and `code`
- [ ] nested tasks
  - [x] done child
  - [ ] pending child

List items containing block content:

1. A paragraph.

   A second paragraph inside the same item.

   ```dart
   void inside() {}
   ```

   > A quote inside a list item.

2. Another item.

Definition-ish list (not GFM — should degrade to plain paragraphs):

Term
: Definition

Lists interrupted by a thematic break:

- before

---

- after
