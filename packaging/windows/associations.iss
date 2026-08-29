; File associations for the MarkLens installer (docs/11_PACKAGING_UPDATE.md).
;
; Included by the Inno Setup script M4 writes. Kept as its own file because the
; association rules are a policy decision — which extensions, checked or not,
; per-user or per-machine — and the rest of the installer is mechanism.
;
; Per-user throughout. Doc 11 requires PrivilegesRequired=lowest and an install
; under %LocalAppData%, so every key below is HKCU: no elevation, nothing left
; behind for other accounts, and no chance of clobbering another user's choice.

[Tasks]
; ".md checked by default, .mdx unchecked — don't steal MDX from editors
; uninvited" (doc 11). MDX files are usually part of a site someone is building
; in an editor, and a viewer that quietly becomes their handler is a viewer
; they uninstall.
;
; GroupDescription is {cm:FileAssociations}, a custom message the including
; script defines. Inno ships no standard heading for associations, and the
; nearest one - {cm:AdditionalIcons}, "Additional shortcuts:" - would put two
; association checkboxes under a heading about shortcuts.
Name: "assocmd";  Description: "{cm:AssocFileExtension,MarkLens,.md}";  \
    GroupDescription: "{cm:FileAssociations}";  Flags: checkedonce
Name: "assocmdx"; Description: "{cm:AssocFileExtension,MarkLens,.mdx}"; \
    GroupDescription: "{cm:FileAssociations}";  Flags: unchecked

[Registry]
; The ProgId itself. Always written, whichever tasks are chosen: it is what
; makes MarkLens appear in "Open with" at all, which doc 11 wants
; unconditionally. Registering a handler is not the same as becoming the
; default one.
Root: HKCU; Subkey: "Software\Classes\MarkLens.Document"; \
    ValueType: string; ValueName: ""; ValueData: "Markdown Document"; \
    Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\MarkLens.Document\DefaultIcon"; \
    ValueType: string; ValueName: ""; ValueData: "{app}\marklens.exe,0"
Root: HKCU; Subkey: "Software\Classes\MarkLens.Document\shell\open\command"; \
    ValueType: string; ValueName: ""; ValueData: """{app}\marklens.exe"" ""%1"""

; "Open with" for both extensions, always — the list a user can pick from.
Root: HKCU; Subkey: "Software\Classes\.md\OpenWithProgids"; \
    ValueType: string; ValueName: "MarkLens.Document"; ValueData: ""; \
    Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Classes\.mdx\OpenWithProgids"; \
    ValueType: string; ValueName: "MarkLens.Document"; ValueData: ""; \
    Flags: uninsdeletevalue

; Becoming the default handler, only for the tasks that were chosen.
Root: HKCU; Subkey: "Software\Classes\.md"; \
    ValueType: string; ValueName: ""; ValueData: "MarkLens.Document"; \
    Flags: uninsdeletevalue; Tasks: assocmd
Root: HKCU; Subkey: "Software\Classes\.mdx"; \
    ValueType: string; ValueName: ""; ValueData: "MarkLens.Document"; \
    Flags: uninsdeletevalue; Tasks: assocmdx

; Only the extensions doc 07 calls the *defaults* are registered, and only two
; of those. The extension registry in Settings decides what this copy will open
; when asked; it is not a request to become the system handler for seven file
; types. A user who adds `.txt` there has not asked to own every text file on
; the machine.
