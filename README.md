# lrzip-fe - an lrzip front-end

usage: `lrzip-fe.sh`  
Output: A command line you can cut and paste and use

## About

Since working on lrzip for the past dozen or so years, a goal has
always been to come up with a usable front-end for it.

As options grew, so did complexity. At first I came up with the
idea of a configuration file that would be loaded with pre-set
options at run-time. This proved very useful to those who
discovered it! But many users do not use a configuration file for
lrzip.

lrzip-fe presents a series of cascading menus and choices to help
users fully explore the capabilities of:

* Compression
* Decompression
* Testing
* Info

Thats's really all there is to lrzip -- that is until you peek
under the hood.

## Thus, lrzip-fe

Version 0.7x of **lrzip** has 39 options. Some are mutually
exclusive, (such as `-O and -o`), other can be combined, but only
in some modes. (see file `lrzip.options.txt`)

If an option is not selected, it is not shown.  If an option is
not selected and has a default value, the default will silently
be used (e.g. lzma compression, versus `--lzma`).  If an
**lrzip.conf** file exists, it's options will be silently used.
Only long options are shown for improved readability.

lrzip-fe does not execute the lrzip program, merely constructs a
command line that may be copied and used.  Hopefully, lrzip-fe
will enhance your usage and understanding of lrzip.

## About Dialog

The **dialog** program uses **ncurses**. There are certain things
to be aware of. **RETURN** select OK. **TAB** moves between
sections of a menu. **Cursor** keys moves between choices
**SPACE** selects an item within a **checkbox** or **radiolist**.
There may be some other quirks about selection.

Your comments and contributions are welcome.

October 2020  
Peter Hyman, pete@peterhyman.com  
https://github.com/pete4abw/lrzip-fe  
https://github.com/pete4abw/lrzip  
