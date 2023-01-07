#!perl -w

package WPath;

use File::Spec (qw(catdir catfile curdir is_case_tolerant file_name_is_absolute
                    splitpath splitdir catpath rel2abs));


# Possilities:
#   vol (possibly empty), path. string string
#   vol (possibly empty), path, file (possibly empty), string string string
#   full path (without file) string
#   full path (with file - and flag) string

# might have to think about how to handle files in these paths.
sub new {
  my $fpath = '';
  my $vol = '';
  my $dir = '';
  my $filename = '';
  my $absolute = 0;
  
  my ($class, $path, $flags) = @_;
  $flags = {} if (!defined $flags);
  
  if (!defined $path) {
    $fpath = File::Spec->rel2abs(File::Spec->curdir());
	($vol, $dir, $filename) = File::Spec->splitpath($fpath, 1);
	$absolute = 1;
  } else {
	$fpath = $path;
	my $nofile = 1;
	if (defined $$flags{has_file} && $$flags{has_file}) {
		$nofile = 0;
    } 
    $absolute = File::Spec->file_name_is_absolute($fpath);
 
    
	($vol, $dir, $filename) = File::Spec->splitpath($fpath, $nofile);
  }
  
  
  my $self = {
    absolute => $absolute,
	fpath => $fpath,
	vol => $vol,
	dir => $dir,
	file => $filename,
  };
  
  bless $self, $class;
  
  return $self;
}


sub Path {
  my $self = shift;
  return File::Spec->catpath($$self{vol},$$self{dir},'');
}

sub Filename {
	my $self = shift;
	return $$self{file};
}

sub Full {
	my $self = shift;
	return $$self{fpath};
}
# for Win32 will return 2 for 'with volume' and 1 for 'without volume'
sub IsAbsolute {
  my $self = shift;
  return $$self{absolute};
}

sub Components {
  my $self = shift;
  return ($$self{vol}, $$self{dir}, $$self{file});
}

sub NewFile {
	my ($self, $nfile) = @_;
	$nfile = '' if !defined $nfile;
	$$self{file} = $nfile;
	$$self{fpath} = File::Spec->catpath($$self{vol},$$self{dir},$$self{file});
	return $$self{fpath};
}

sub Duplicate {
	my ($self, $withfile) = @_;
	$withfile = 0 if (!defined $withfile);
	my $tfile = ($withfile ? $$self{file} : '');
	my $newfpath = File::Spec->catpath($$self{vol},$$self{dir},$tfile);
    my $newpath = new WPath($newfpath,$withfile);
	return $newpath;
}

sub Compare {
  my $self = shift;
  return undef if (!@_);
  my ($comp) = @_;
  my ($uspath, $thempath) = ( '', '');
  $uspath  = $$self{fpath};
  if (ref($comp) eq ref($self)) {
	  $thempath = $comp->Full();
  } elsif (!ref ($comp)) {  # assume string
    if (File::Spec->file_name_is_absolute($comp)) {
	   $thempath = $comp;
	} else {
	  $thempath = File::Spec->rel2abs($comp);
	}
  }
  if (!$thempath) {
	 return undef;
  }
  return ($uspath cmp $thempath);
}

# if 'makenew' is set, then the original is not changed, only the new
# One is absolute.
sub ToAbsolute {
  my $self = shift;
  my ($basedir, $makenew) = @_;
  if (!defined $makenew) {
	    $makenew = 0;
  }
  if ($makenew) {  # duplicate and then go throufh ToAbsolute.
	  my $newpath = Dupicate($self, 1);
	  return $newpath->ToAbsolute($basedir, 0);
  }
  if ($$self{isabsolute}) {
     return $self;
  }
  if (defined $basedir && (ref($basedir) eq 'WPath')) {
	 $basedir = $basedir->Path();
  }
  my $tbasedir = (defined $basedir ? $basedir : undef);
  $$self{fpath} = File::Spec->rel2abs($$self{fpath}, $tbasedir);
  
	# now reconstruct the vol/dir/etc stuff
  my $nofile = 1;
  $nofile = 0 if ($$self{file});
  ($$self{vol},$$self{dir},$$self{file}) = File::Spec->splitpath($$self{full},$nofile);
  $$self{isabsolute} = 1;
  return $self;
}

1;

	 