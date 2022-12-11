# AutoCrop
 Attempt to automatically crop pictures, regardless of how uneven the borders are.
 
 Requires:
   * ImageMagick
   * PerlMagick
 
History
------- 
 This was written to clean up a whole stack of photos I've downloaded from the web for use on my private Digital Photo Frame (an old Samsung Tablet).
 
 Most cropping tools I've come across work reasonably well when the border is even (i.e the same number of pixels on all sides), but fail when the border is only top or bottom (for example) or the borders are something like 4px on top and bottom, and 24 on left and right.
 
 Current Status
 --------------
 This is still very much in development and is mostly being developed in a Windows environment.  I'm trying to keep all of the file/directory stuff unisex so it should work on Linux/MAC.  However this hasn't been tested yet.
 
 A lot of the options have been put in to allow me to debug the concept of 'tolerances' (since black is so rarely rgb 000 in computer graphics).  It's also helped me work out what tolerances to use to remove the most amount of border with the least amount of real image.
 
 There are still a lot of bugs, and many of the options are 'aspirational' rather than coded yet.
 
 
