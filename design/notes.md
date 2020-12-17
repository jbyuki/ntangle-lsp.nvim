Notes
-----

Implementation
--------------

* As much as possible, it should use builtin facilities to leverage LSP tasks

Observations
------------

* One source location (one line in ntangle source file) can map to several target location (in generated file). This needs to be resolved to handle functionnalities such as search for definition or any client requests really. One solution could be to present the user with a popup where he could choose which target line he want to request.
