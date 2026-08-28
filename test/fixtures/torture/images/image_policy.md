# Image policy

Local images only by default, extension-allowlisted, size-capped (docs/04).

## Allowed extensions

![png](../assets/nonexistent.png)
![jpg](../assets/nonexistent.jpg)
![jpeg](../assets/nonexistent.jpeg)
![gif](../assets/nonexistent.gif)
![webp](../assets/nonexistent.webp)
![bmp](../assets/nonexistent.bmp)
![svg](../assets/badge.svg)

## Outside the allowlist — placeholder, never loaded

![pdf](../assets/document.pdf)
![exe](../assets/installer.exe)
![no extension](../assets/mystery)
![dotfile](../assets/.hidden)

## Path shapes

![absolute posix](/etc/hostname)
![parent traversal](../../../../../../etc/passwd)
![with spaces](../assets/name%20with%20spaces.png)
![with query](../assets/badge.svg?v=2)
![with fragment](../assets/badge.svg#fragment)

## Remote — blocked placeholder showing the URL, default off

![http](http://example.com/insecure.png)
![https](https://example.com/tracker.png)
![protocol relative](//example.com/tracker.png)
![data uri](data:image/gif;base64,R0lGODlhAQABAAAAACw=)

## A badge row, as a README would have it

![build](../assets/badge.svg) ![coverage](../assets/badge.svg) ![license](../assets/badge.svg)

## Image as a link target

[![clickable badge](../assets/badge.svg)](https://example.com)

## Empty and malformed

![]()
![alt only]()
![](../assets/badge.svg)
![malformed svg](../assets/malformed.svg)

## Network locations wearing a path — refused, never statted

A protocol-relative URL has no scheme, so it falls through every scheme check;
a UNC path is not parsed as a URI at all. Both are an SMB connection to a host
the document chose, which is what invariant 4 forbids by default (docs/10).

![protocol relative svg](//example.com/badge.svg)
![unc](\\server\share\badge.png)
