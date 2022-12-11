#!perl -w
package TRecord;

sub new {
  my $class = shift;
  my ($name, $min, $max) = @_;
  $name = 'Tolerance' if ! defined $name;
  $min = 0 if ! defined $min;
  $max = 1 if ! defined $max;
  my $self = {
     max_max_T => $max,
	 min_min_T => $min,
	 max_T => $min,
	 min_T => $max,
	 name => $name,
	 
  };
  bless $self, $class;
  return $self;
}

sub CheckTolerance {
    my $self = shift;
	return undef if !@_;
	my ($newval) = @_;
	if ($newval > $$self{max_max_T}) {
		return undef;  #out of range
	}
	if ($newval < $$self{min_min_T}) {
		return undef;  # out of range
	}
	my $changed = 0;
	if ($newval < $$self{min_T}) {
	   $$self{min_T} = $newval;
	   $changed++;
	}
	if ($newval > $$self{max_T}) {
		$$self{max_T} = $newval;
		$changed++;
	}
	return $changed;
}

sub GetBounds {
     my $self = shift;
	 return ($$self{min_min_T}, $$self{max_max_T});
}

sub GetTolerances {
	 my $self = shift;
	 return ($$self{min_T}, $$self{max_T});
}

sub GetName {
  	my $self = shift;
	return $$self{name};
}
	 
1; 