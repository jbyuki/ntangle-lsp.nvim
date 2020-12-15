Transpilation
-------------

Strong: typescript, dart, coffescript,...
Weak: ntangle

Weak: reordering, duplication, removal
Strong: reordering, duplication, removal, replace with other

Diagram
-------

Normal LSP:

text edits
    |
	v
LSP client
    |
	v
LSP server

LSP coupled with ntangle:

text edits
    |
	v
ntangle translation
    |
	v
LSP client
    |
	v
LSP server
