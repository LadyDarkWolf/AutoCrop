#!perl -w
use strict;
use lib './';  #This needs to change depending on where TRecord.pm is and where you run this from
use Cwd qw(getcwd cwd);

use Image::Magick;
use TRecord;

use Getopt::Long qw(:config no_ignore_case bundling);

my($image, $x); 
my $PGROUP = 3; # number of array elements for each pixel from GetPixels

my $crop_colour = undef;
my $ccrop_colour = undef;


# Things changed by GetOptions
my $sdir = '';
my $ddir = '';
my $out_fname = '';
my $in_fname = '';
my $crop_colour_text = '';
my $docrop = 1;
my $UPDATE = 0;
my $DEBUG = 0;
my $overwrite = 0;
my $top = 0;
my $bottom = 0;
my $left = 0;
my $right = 0;
my $all = 1;
my $create_dir = 0;
my $tolerance = 0.0;
my $suffix = '_trimmed';

my $rv = GetOptions(
           'source_dir|src_dir|sdir=s' => \$sdir,
		   'destination_dir|dest_dir|ddir=s' => \$ddir,
		   'CREATE_DIR|CREATE-DIR|CD!' => \$create_dir,
		   'suf|s|suffix:s' => \$suffix,
		   'UPDATE|U!' => \$UPDATE,
		   'D|DEBUG+' => \$DEBUG,
		   'cc|crop_colour|crop_color=s' => \$crop_colour_text,
		   'C|crop!' => \$docrop,
		   't|tol|tolerances=s' => \$tolerance,
		   'T|top!' => \$top,
		   'B|bot|bottom!' => \$bottom,
		   'L|left!' => \$left,
		   'R|rite|right!' => \$right,
		   'A|all' => \$all,
		   'O|overwrite!' => \$overwrite,
		   'out|out_file|output_file=s' => \$out_fname,
		   'in|in_file|input_file=s' => \$in_fname);
		   
my @ierrors = (); # input errors

if (!$sdir || ($sdir eq './')) {
   $sdir = '.';
}
if (!$ddir) {
	$ddir = "$sdir";
}
if ((substr($ddir,0,1) ne '/') &&
    (substr($ddir,0,1) ne '.') &&
	($ddir !~ m/^[a-z]:/i)) { # force through next check.
  $ddir = "./$ddir";
}
if (substr($ddir,0,2) eq './') {  
  if (length($ddir) > 2) {
	 $ddir = substr($ddir,2);
	 $ddir = "$sdir/$ddir";
  } else {
	  $ddir = $sdir;
  }
}

if ((($ddir eq $sdir) || !$ddir) &&
    !$suffix && !$overwrite) {
   push @ierrors, "Source and Dest directories are same, you've given an empty suffix, but no ovewrite option";
}
if (!-d "$sdir" && !$create_dir) {
	push @ierrors, "Souce directory '$sdir' doesn't exist and CREATE_DIRECTORY option not set\n";
}
if (!-d "$ddir" && !$create_dir) {
	push @ierrors, "Destination directory '$ddir' doesn't exist and CREATE_DIRECTORY option not set\n";
}

if ($tolerance) {
  if ($tolerance !~ m/^\d*\.\d+$/) {
	push @ierrors, "Tolerance ($tolerance) must be floating point (i.e. 0.3, etc)";
  } else {
	  if (($tolerance < 0.0) || ($tolerance > 1.0)) {
		 push @ierrors, 'Tolerance must be between 0 and 1';
	  }
  }
}

if (0) {
if ($crop_colour_text) {
  # must validate this input!
  my ($r, $g, $b) = split /,/, $crop_colour_text;
  if (!defined $r || !defined $g || !defined $b) {
	 push @ierrors, "Format of crop_colour is r,g,b (where r, g or b must be 0-1)";
  } elsif (($r < 0) || ($r >1) || ($g < 0) || ($g > 1) ||
    ($b < 0) || ($b > 1)) {
		# error
  }
  $crop_colour = [$r, $g, $b];
} 
} # comment out for now
if ($top || $bottom || $left || $right) {
   $all = 0;
}
if ($all) {  # make sure we crop on all sides.
  $top = $bottom = $left = $right = 1;
}
if (@ARGV) {
	foreach my $arg (@ARGV) {
		if (substr($arg,0,1) eq '-') {
			push @ierrors, "Unknown argument '$arg'";
		}
	}
}
if ($in_fname && (!-f "$in_fname")) {
   if (-f "$sdir/$in_fname") {
	  $in_fname = "$sdir/$in_fname";
   } else {
	   push @ierrors, "input filename '$in_fname' doesn't exist";
   }
}
# Check for where we write to out fname
if ($out_fname) {
	if (index($out_fname,'/') >= 0) { # probably has a path.
		my @path = split /\//, $out_fname;
		pop @path;  # get rid of filename.
		my $npath = join ( '/', @path);
		if (!-d "$npath") {
			push @ierrors, "Can't write to filename/path $out_fname\n";
		}
	} else { #tack '$ddir' onto it
		$out_fname = "$ddir/$out_fname";
	}
}

if (@ierrors) {
	usage (@ierrors);
	exit 1;
}

sub usage {
	my (@errors) = @_;
	print "Errors:\n";
	foreach my $err (@errors) {
		print "\t * $err\n";
	}
	print "\n";
	print "AutoCrop.pl\n";
    print "\tCommand line options:\n";
	print "\t\t(Those with '*' after them can be prepended with 'no' to invert their meaning)\n";
    print "\t\t--sdir=DIR = Source directory for images\n";
    print "\t\t\t\t(aliases: --src_dir, --source_dir)\n"; 
	print "\t\t\t\tIf not given will default to 'current' directory\n";
    print "\t\t--ddir=DIR = Destination directory for images\n";
    print "\t\t\t\t(aliases: --dest_dir, --destination_dir)\n"; 
	print "\t\t\t\tIf not given, default to putting images in the source directory\n";
    print "\t\t--suffix=STRING = suffix to append to filename (before the extension)\n";
	print "\t\t\t\t(aliases: --suf, --s)\n";
	print "\t\t\t\tSTRING may be empty or ''\n";
	print "\t\t--UPDATE* = actually do the work.  This will calculate and output the\n";
	print "\t\t\tcropped image with the rules given\n";
	print "\t\t\t\t(aliases: --U)\n";
	print "\t\t--DEBUG* = output debugging information to stdout and stderr\n";
	print "\t\t\t\t(aliases: --D)\n";
}	
$tolerance *= 1;
if ($DEBUG > 0) {
	print "Source Dir: $sdir\n";
	print "Dest Dir: $ddir\n";
	print "Suffix: $suffix\n";
	print "Tolerance: $tolerance\n";
	print "Docrop: $docrop\n";
	print "Input Filename: $in_fname\n";
	print "Output filename: $out_fname\n";
	if ($all) {
	  print "Crop All\n";
	} else {
	  print "Crop:\n";
	  print "\tTop:    $top\n";
	  print "\tBottom: $bottom\n";
	  print "\tLeft:   $left\n";
	  print "\tRight:  $right\n";
	} 
	print "DEBUG: $DEBUG\n";
	print "UPDATE: $UPDATE\n";
}


# Main read loop
if ($out_fname) {
	if (!open(OUTFILE, ">$out_fname")) {
	  print STDERR "Unale to open '$out_fname' for writing\n";
	  exit 1;
	}
}
if ($in_fname) {
	if (!open(INFILE, "<$in_fname")) {
			print STDERR "Unable to open '$in_fname' for reading\n";
			exit 1;
	}
} else {
	if (!opendir(INDIR,"$sdir")) {
		print STDERR "Can't open\n";
		exit 1;
	}
}
while (1) {
	my $fname = '';
	my $fsdir = $sdir;
	my $fddir = $ddir;
	if ($in_fname) {
	  $fname = <INFILE>;
	  last if !$fname;
	  chomp $fname;
	  next if ($fname =~ m/^\s*$/);
	  my @path = split /\//, $fname;
	  $fname = pop @path;
	  $fsdir = join('/', @path);
	} else {
		$fname = readdir(INDIR);
		last if (!$fname);
    }
	if (!-f "$fsdir/$fname") {
		next;
	}
	my ($inname,$type) = split /\./, $fname;
	my $ttype = uc $type;
	if (!defined $ttype ||
	    (($ttype ne 'JPG') &&
	    ($ttype ne 'JPEG') &&
	     ($ttype ne 'PNG'))) {
	   next;
	}
	my $outname = $inname . "$suffix";
	print "FILE:$inname,$type,$outname\n";
	my $im= Image::Magick->new;
	my $x = $im->Read("$fsdir//$fname");
	warn "$x" if "$x";
	my $itol = new TRecord('image',0,1);
	$x = Calculate($im, $crop_colour, $itol);
	my ($mint, $maxt) = $itol->GetTolerances();
	print "Image tolerances: $mint - $maxt\n";
	
	if ($x > 0) { # something changed
		if ($out_fname) {
			print OUTFILE "$fsdir/$fname\n";
		}		 
		if ($UPDATE) {
			$x = $im->Write("$ddir/$outname.$type");
			warn "$x" if "$x";
			print "Written\n";
		}
	} elsif ($x < 0) {
		  print "Error processing: $x\n";
		  exit 1;
	} else {
		 # nothing changed
		 print "nothing changed\n";
	}
}
if ($out_fname) {
  close(OUTFILE);
} 
if ($in_fname) {
		close(INFILE);
} else {
	closedir(INDIR);
}

sub Calculate {
	my ($im, $crop_colour,$tol) = @_;
	my ($h, $w) = $im->Get('height','width');
	my ($x1,$y1,$x2,$y2) = (-1, -1, $w, $h);
	foreach my $dir (qw(L R U D)) {
		# take care of which bits to scan.
		if (($dir eq 'L') && !$right) {
			next;
		}
		if (($dir eq 'R') && !$left) {
			next;
		}
		if (($dir eq 'D') && !$top) {
			 next;
		}
		if (($dir eq 'U') && !$bottom) {
			next;
		}
		my ($rc,$detail) = Scan($im, $crop_colour, $dir, $tol);
		if ($rc == 0) {
			print "Error scanning:\n";
			foreach my $l (@$detail) {
				print "\t$l\n";
			}	
			return -1;
		} elsif ($rc == 1) { # all good
			foreach my $k (sort keys %$detail) {
				if ($DEBUG) {
					if (defined $$detail{$k}) {
						print "\t$k=$$detail{$k}\n";
					} else {
						print "\t$k=[undef]\n";
					}
				}
				if ($k eq 'crop_colour') {
					$crop_colour = $$detail{$k};
				} elsif (($dir eq 'L') && defined $$detail{$k} &&
				             ($k eq 'x')) {
					$x2 = $$detail{$k};
				} elsif (($dir eq 'R') && defined $$detail{$k} &&
				             ($k eq 'x')) {
					$x1 = $$detail{$k};
				} elsif (($dir eq 'D') && defined $$detail{$k} &&
				             ($k eq 'y')) {
					$y1 = $$detail{$k};
				} elsif (($dir eq 'U') && defined $$detail{$k} &&
         				    ($k eq 'y')) {
					$y2 = $$detail{$k};
				}
			}	
		} else {
			print "Unexpected return: $rc\n";
			return -1;
		}	
	}
	if ($docrop) {
		print "RAW $x1,$y1, $x2, $y2\n" if $DEBUG;
	
		if (($x1 == -1) && ($y1 == -1) &&
			($x2 == $w) && ($y2 == $h)) {
			# nothing changed.
			return 0;
		}	
		# at this point note that the xy etc are on the last pixel of the bit to be cropped
		# off, and Crop is 'inclusive' of boundaries.  So fix this and then do sanithy checks.
	
	
		# now, push into actual image. 
		$x1 += 1; # note, if -1 then this will set to 0 - correct
		$x2 -= 1; # note, if $width, then this will set to width-1, correct
		$y1 += 1; # note if -1 then this will set to 0 - correct
		$y2 -= 1; # note if $height then this will set ot height-1, correct
		print "CALCULATED  $x1,$y1, $x2, $y2\n" if $DEBUG;
	
		if (($x1 > $x2) ||
			($y1 > $y2)) {
			print "Recalculated corners passed each other, $x1,$y1,$x2,$y2\n";
			return 0;
		}
    	
		my $cwidth = $x2-$x1+1;
		my $cheight = $y2-$y1+1;
		print "Crop WxHo: $cwidth, $cheight\n" if $DEBUG;
		if ($UPDATE) { # don't bother wasing time if we're not updating
			$im->Crop(x=>$x1, y=>$y1,width=>$cwidth,height => $cheight);
		}
	}
	return $docrop;
} # Calculate


# Just to be confusing, '$dir' is which way to scan.
#  What this means is that 
#     'L' means scan left, which implies you start at the right.
#     'U' means scan up, so you start from the bottom.
#     'R' means scan right, so you start from the left
#     'D' means scan down, so you start from the top.

sub Scan {
	my ($im, $crop_colour, $dir, $itol) = @_;
	my ($h, $w) = $im->Get('height','width');
	my ($sx, $sy) = ( 0, 0);
	my ($ex, $ey) = (0, 0);
	my ($incx, $incy) = (0, 0);
	my $depth = 2**$im->QuantumDepth();
	my $ocrop_colour = undef;
	print "Scan $dir\n" if $DEBUG;
	print "Depth: $depth\n" if $DEBUG;
	my $ndir = uc (substr($dir,0,1));
	if ($ndir eq 'U') { # scan up
	  $sx = 0;
	  $ex = $w - 1;
	  $sy = $h -1;  # start at bottom left.
	  $ey = 0;
	  $incy = -1;
	  $incx = 1;
	} elsif ($dir eq 'D') { # scan down
	  $sx = 0;
	  $ex = $w -1;
	  $sy = 0;
	  $ey = $h - 1;
	  $incx = 1;
	  $incy = 1;
    } elsif ($dir eq 'R') { # scan right
	  $sx = 0;
	  $ex = $w-1;
	  $sy = 0;
	  $ey = $h-1;
	  $incx = 1;
	  $incy = 1;
	} elsif ($dir eq 'L') { # scan left  
	  $sx = $w - 1;
	  $ex = 0;
	  $sy = 0;
	  $ey = $h - 1;
	  $incx = -1;
	  $incy = 1;
	} else {
	  return (0,["Unknown direction '$dir'"]);
	}
	if (!$incx && !$incy) {
	  return (0,["Something went wrong with '$dir'. incx: $incx, incy: $incy"]);
	}
	# two separate types of loop, depending on scanning.  
	#   L & R scan mean we scan y 0->height, then move to the next x
	#   U & D scan mean we scan x 0->width, then move to the next y
	if (($dir eq 'L') || ($dir eq 'R')) {  # x loop outside y loop
	    my $lgx = undef;
		my $x = $sx;
		do {
			my $ctol = new TRecord("Col $x", 0, 1);
			my @pixels = $im->GetPixels(x=>$x, y=>$sy,
			                            width=> 1,
										height => $h);
			my $y = 0;
			my $plen = scalar @pixels;
            print "$x,$sy (1,$h):\n" if $DEBUG;
			while ($y < ($plen/$PGROUP)) {
			  my $fauxy = $y*$PGROUP;
              my ($r, $g, $b) = @pixels[$fauxy..$fauxy+($PGROUP-1)];
			  
			  print "\t$x,$y: $r, $g, $b\n" if $DEBUG;
		      if (!defined $crop_colour) {
				  $ocrop_colour = [$r, $g, $b];
				  $crop_colour = Convert($r, $g, $b, $depth);
			  } else {
				 my $cc = Convert($r, $g, $b, $depth);
				 my $comp = Compare($crop_colour, $cc, $ctol);
				 if ($docrop  && !$comp) {
					# return what we've found so far.
					my ($min, $max) = $ctol->GetTolerances();
					if ($DEBUG > 0) { 
						print $ctol->GetName() . ": $min, $max\n"
					}
					$itol->CheckTolerance($min);
					$itol->CheckTolerance($max);

					return (1,{x=>$lgx, crop_colour => $crop_colour});
				}		   
			  }
			  $y+=$incy;			 
		    }
			$lgx = $x;
			$x += $incx;
			my ($min, $max) = $ctol->GetTolerances();
			if ($DEBUG > 0) {
				print "Tolerance: " . $ctol->GetName() . ": $min, $max\n"
			}
			$itol->CheckTolerance($min);
            $itol->CheckTolerance($max);			
		} while ( $x != $ex );
		return (1, { x=> $lgx, crop_colour => $crop_colour});
	}
	
	if (($dir eq 'U') || ($dir eq 'D')) {  # y loop outside x loop
	    my $lgy = undef;
		my $y = $sy;
		do {
			my $rtol = new TRecord("Row $y", 0, 1);
			my @pixels = $im->GetPixels(x=>$sx, y=>$y,
			                            width=> $w,
										height => 1);
			my $x = 0;
			my $plen = scalar @pixels;
            print "$sx,$y ($w,1):\n" if $DEBUG;
			while ($x < ($plen/$PGROUP)) {
			  my $fauxx = $x * $PGROUP;
              my ($r, $g, $b) = @pixels[$fauxx..$fauxx+($PGROUP-1)];
			  print "\t$x,$y: $r, $g, $b\n" if $DEBUG;
		      if (!defined $crop_colour) {
				  $ocrop_colour = [$r, $g, $b];
				  $crop_colour = Convert($r, $g, $b, $depth);
			  } else {
					my $cc = Convert($r, $g, $b, $depth);
					my $comp = Compare ($crop_colour, $cc, $rtol);
					if ($docrop && !$comp) {
					   # return what we've found so far.
					   	my ($min, $max) = $rtol->GetTolerances();
						if ($DEBUG > 0) { 
							print $rtol->GetName() . ": $min, $max\n"
						}
						$itol->CheckTolerance($min);
						$itol->CheckTolerance($max);
						return (1,{y=>$lgy, crop_colour => $crop_colour});
			        }		   
			  }
			  $x+=$incx;			 
		    }
			$lgy = $y;
			$y += $incy;
			my ($min, $max) = $rtol->GetTolerances();
			if ($DEBUG > 0) {
				print "Tolerance: " . $rtol->GetName() . ": $min, $max\n"
			}
			$itol->CheckTolerance($min);
            $itol->CheckTolerance($max);
		} while ( $y != $ey );
		return (1, { y=> $lgy, crop_colour => $crop_colour});
	}

}

sub Convert {
	my ($r, $g, $b, $depth) = @_;
	my @cc = ( $r, $g, $b );
	foreach my $c (@cc) {
		$c = $c/$depth;
	}
	return \@cc;
}

sub Compare {
	my ($c1, $c2, $tol) = @_;
	my ($r1, $g1, $b1) = @$c1;
	my ($r2, $g2, $b2) = @$c2;
	my $tr = abs($r1-$r2) ;
	$tol->CheckTolerance($tr);
	printf "R,%.05f,%.05f,%.05f", $r1, $r2, $tr if ($DEBUG>2);
	my $tg = abs($g1-$g2) ;
	$tol->CheckTolerance($tg);
	printf "G,%.05f,%.05f,%.05f", $g1, $g2, $tg if ($DEBUG>2);
	my $tb = abs($b1-$b2) ;
	$tol->CheckTolerance($tb);;
	printf "B,%.05f,%.05f,%.05f", $b1, $b2, $tb if ($DEBUG>2);
    print "\n" if $DEBUG;
	
	return ($tr <= $tolerance) &&
            ($tg <= $tolerance) &&
			($tb <= $tolerance)
}