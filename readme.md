20080706

JagLion.cof - http://harmlesslion.com - by Tursi at the same address. ;)

This is just a quick and dirty demo of some code I was playing with. You get to control a stylized morphic white lion as he strides left or right on an eternal plane.

The code I was working on was a real-time sprite RLE decompression routine. This little guy here occupies 8000 bytes of 8-bit memory, yet there are 51 frames packed into just over 100k (uncompressed size is over 400,000 bytes!) The routine does not only an RLE pack of the data, but does a difference with the previous frame, which usually helps get 3:1 to 4:1 ratios on animation sequences.

It's not quite ready for use as a library yet - for one thing the output buffer is fixed, but it's not hard to update it, and if you want to use it I can help you with that. In the meantime, enjoy some smooth animation on your Jag. ;)

Use: COF file, use however you normally would!

-Works in BJL.
-Works in Project Tempest if you lie to the emulator a little. Change the file selector to "all files", and use 3F58 as the load address, and 4000 as the run address.
-works with any other decent debugging tool, I would imagine!

Once running - move the joystick left, right, or down. That's all.

Source is provided for curiousity's sake only. If you want to use anything from it,
you gotta ask! ;)

Updated version on 6 Jul 08 - fixes a lot of the startup code and a few small bugs causing instability.
