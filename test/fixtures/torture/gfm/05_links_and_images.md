# Links and images

Inline link: [example](https://example.com).

Link with a title: [example](https://example.com "Title text").

Reference link: [reference style][ref], and a collapsed one: [ref][].

[ref]: https://example.com/reference "Reference target"

Relative document links, which open in-app (docs/03):

- [sibling document](./01_headings_and_text.md)
- [parent directory](../bytes/bom.md)
- [with an anchor](./01_headings_and_text.md#duplicate-heading)

Same-document anchor: [jump to duplicate heading](#duplicate-heading).

Link types that must be refused with a notice, never shelled out (docs/10):

- [file scheme](file:///etc/passwd)
- [javascript scheme](javascript:alert%281%29)
- [custom scheme](marklens-internal://do-something)

Local image, relative path:

![local badge](../assets/badge.svg)

Image with a missing target — placeholder showing the resolved path:

![missing](../assets/definitely-not-here.png)

Remote image — blocked placeholder by default (docs/04):

![remote](https://example.com/remote-image.png)

Image with an extension outside the allowlist:

![not an image](../assets/document.pdf)

Reference-style image: ![alt text][img]

[img]: ../assets/badge.svg

Link whose text contains braces, which the MDX scanner must not touch here:
[a {braced} link](https://example.com).

Empty link text: [](https://example.com)

Nested brackets: [outer [inner] text](https://example.com)
