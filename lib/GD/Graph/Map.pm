package GD::Graph::Map;

use GD::Graph::axestype;
use GD::Graph::utils qw(:all);
use strict qw(vars subs refs);
use vars qw(@EXPORT_OK $VERSION);
require Exporter;

@GD::Graph::Map::ISA = qw(Exporter);
@EXPORT_OK = qw(set imagemap);
$VERSION = 1.03;

#--------------------------------------------- set defaults
my $ANGLE_OFFSET = 90;
my %Defaults = ( #Default Href is JavaScript code, which do nothing
                 href   => 'javascript:;',
                 lhref  => 'javascript:;',
                 hrefs  => [],
                 lhrefs => [],
                 #Default information and legend
                 info   => 'x=%x   y=%y',
                 legend => '%l',
                 #Line width for lines and linespoints graph
                 linewidth => 3,
               );

my %No_Tags = ('img_src'   => 0, 'img_usemap' => 0, 'img_ismap'   => 0,
               'img_width' => 0, 'img_height' => 0 , 'img_border' => 0);


#********************************************* PUBLIC methods of class

#--------------------------------------------- constructor of object
sub new #($graphs, [%options])
{ my $type = shift;
  my $class = ref $type || $type;
  my $self = {GDGraph => shift, %Defaults};
  bless $self, $class;
  $self->set(@_) if @_;
  return $self;
} #new

#--------------------------------------------- routine for set options
sub set
{ my $self = shift;
  my %options = @_;
  map
  { $self->{$_} = $options{$_} unless exists $No_Tags{lc($_)}
  } keys %options;
} #set

#--------------------------------------------- routine for make image maps
sub imagemap($$$) #($file, \@data)
{ my $self = shift;
  my $type = ref $self->{GDGraph};
  if ($type eq 'GD::Graph::pie') { $self->piemap(@_) }
  elsif ($type eq 'GD::Graph::bars') { $self->barsmap(@_) }
  elsif ($type eq 'GD::Graph::lines') { $self->linesmap(@_) }
  elsif ($type eq 'GD::Graph::points') { $self->pointsmap(@_) }
  elsif ($type eq 'GD::Graph::linespoints') { $self->pointsmap(@_,1) }
  else {die "object $type is not supported"};
} #imagemap


#********************************************* PRIVATE methods of class


#--------------------------------------------- make map for Lines graph
sub linesmap($$) #($file, \@data)
{ my $self = shift;
  my $file = shift;
  my $data = shift;
  my $gr = $self->{GDGraph};
  my $lw = int (($self->{linewidth} + 1) / 2);
  my $name = defined $self->{mapName} ? $self->{mapName} : time;
  my $s = "<Map Name=$name>\n";
  my $ds;
  foreach $ds (1 .. $gr->{numsets})
  { $s .= "\t<Area Shape=polygon Coords=\"";
    my @points;
    foreach (0 .. $gr->{numpoints})
    { my ($x, $y) = $gr->val_to_pixel($_ + 1, $data->[$ds][$_], $ds);
      push @points, [$x, $y];
      $s .= "$x, @{[$y - $lw]}, ";
    } #foreach
    foreach (reverse @points)
    { my ($x, $y) = @$_;
      $s .= "$x, @{[$y + $lw]}, ";
    } #foreach
    chop $s; chop $s;
    my $href = $self->{lhrefs}->[$ds - 1];
    $href = $self->{lhref} unless defined($href);
    $href =~ s/%l/$gr->{legend}->[$ds - 1]/g;
    my $info = $self->{info};
    $info =~ s/%l/$gr->{legend}->[$ds - 1]/g;
    $s .= "\" Href=\"$href\" Title=\"$info\" Alt=\"$info\" onMouseOver=\"window.status=\'$info\'; return true;\" onMouseOut=\"window.status=\'\'; return true;\"";
    if ($self->{newWindow} and not $href =~ /javascript:/i)
    { my $s_;
      map
      { $s_ .= "$1=@{[$self->{$_}]}," if $_ =~ /window_(\w+)/i and $self->{$_};
      } keys %$self;
      chop $s_;
      $s .= " Target=\"_$name\" onClick=\"window.open(\'\', \'_$name\', \'$s_\'); return true;  \"";
    } #if
    $s .= ">\n";
  } #foreach
  $s .= $self->imagelegend($file, $data) if defined($gr->{legend});
  $s .= "</Map>\n";
  unless ($self->{noImgMarkup})
  { $s .= "<Img UseMap=#$name Src=\"$file\" border=0 Height=@{[$gr->{height}]} Width=@{[$gr->{width}]} ";
    map
   { $s .= "$1=@{[$self->{$_}]} " if $_ =~ /img_(\w+)/i and $self->{$_};
   } keys %$self;
   chop $s;
   $s .= ">\n";
  } #unless
  return $s;
} #linesmap


#----------------------------------- Make map for Points and LinesPoints graphs
sub pointsmap($$$) #($file, \@data, $lines)
{ my $self = shift;
  my $file = shift;
  my $data = shift;
  my $lines = shift;
  my $gr = $self->{GDGraph};
  my $lw = int (($self->{linewidth} + 1) / 2) if $lines;
  my $name = defined $self->{mapName} ? $self->{mapName} : time;
  $gr->check_data($data);
  $gr->setup_coords($data);
  my $s = "<Map Name=$name>\n";
  my ($ds, $s1);
  foreach $ds (1 .. $gr->{numsets})
  { my $type = $gr->pick_marker($ds);
    my ($i, @points);
    foreach $i (0 .. $gr->{numpoints})
    { next if (!defined($$data[$ds][$i]));
      my ($xp, $yp) = $gr->val_to_pixel($i+1, $$data[$ds][$i], $ds);
      if ($lines)
      { push @points, [$xp, $yp];
        $s1 .= "$xp, @{[$yp - $lw]}, ";
      } #if
      my $l = $xp - $gr->{marker_size};
      my $r = $xp + $gr->{marker_size};
      my $b = $yp + $gr->{marker_size};
      my $t = $yp - $gr->{marker_size};
      if    ($type <= 4) {$s .= "\t<Area Shape=rect Coords=\"$l, $t, $r, $b\" "}
      elsif ($type == 5) {$s .= "\t<Area Shape=polygon Coords=\"$l, $yp, $xp, $t, $r, $yp, $xp, $b\" "}
      elsif ($type >= 6) { $s .= "\t<Area Shape=circle Coords=\"$xp, $yp, @{[2 * $gr->{marker_size}]}\" "}
      my $href = ${$self->{hrefs}}[$ds - 1][$i];
      $href = $self->{href} unless defined($href);
      $href =~ s/%x/$data->[0][$i]/g; $href =~ s/%y/$data->[$ds][$i]/g;
      $href = $1.(sprintf "%$2f", $data->[0][$i]).$3 if ($href =~ /(^.*)%(\.\d)x(.*&)/);
      $href = $1.(sprintf "%$2f", $data->[$ds][$i]).$3 if ($href =~ /(^.*)%(\.\d)y(.*$)/);
      $href =~ s/%l/@{$gr->{legend}}->[$ds - 1]/g;
      my $info = $self->{info};
      $info =~ s/%x/$data->[0][$i]/g; $info =~ s/%y/$data->[$ds][$i]/g;
      $info = $1.(sprintf "%$2f", $data->[0][$i]).$3 if ($info =~ /(^.*)%(\.\d)x(.*&)/);
      $info = $1.(sprintf "%$2f", $data->[$ds][$i]).$3 if ($info =~ /(^.*)%(\.\d)y(.*$)/);
      $info =~ s/%l/@{$gr->{legend}}->[$ds - 1]/g;
      $s .= "Href=\"$href\" Title=\"$info\" Alt=\"$info\" onMouseOver=\"window.status=\'$info\'; return true;\" onMouseOut=\"window.status=\'\'; return true;\"";
      if ($self->{newWindow} and not $href =~ /javascript:/i)
      { my $s_;
        map
        { $s_ .= "$1=".$self->{$_}."," if (($_ =~ /window_(\w*)/i) and ($self->{$_} != 0))
        } keys %{$self};
        chop $s_;
        $s .= " Target=_$name";
        $s .= " onClick=\"window.open(\'\', \'_$name\', \'$s_\'); return true;\"";
      } #if
      $s .= ">\n";
    } #foreach
    if ($lines)
    { foreach (reverse @points)
      { my ($x, $y) = @$_;
        $s1 .= "$x, @{[$y + $lw]}, ";
      } #foreach
      chop $s1; chop $s1;
      my $lhref = $self->{lhrefs}->[$ds - 1];
      $lhref = $self->{lhref} unless defined($lhref);
      $lhref =~ s/%l/$gr->{legend}->[$ds - 1]/g;
      my $legend = $self->{legend};
      $legend =~ s/%l/$gr->{legend}->[$ds - 1]/g;
      $s .= "\t<Area Shape=polygon Coords=\"$s1\" Href=\"$lhref\" Title=\"$legend\" Alt=\"$legend\" onMouseOver=\"window.status=\'$legend\'; return true;\" onMouseOut=\"window.status=\'\'; return true;\"";
      if ($self->{newWindow} and not $lhref =~ /javascript:/i)
      { my $s_;
        map
        { $s_ .= "$1=@{[$self->{$_}]}," if $_ =~ /window_(\w+)/i and $self->{$_};
        } keys %$self;
        chop $s_;
        $s .= " Target=\"_$name\" onClick=\"window.open(\'\', \'_$name\', \'$s_\'); return true;  \"";
      } #if
      $s .= ">\n"; $s1 = "";
    } #if
  } #foreach
  $s .= $self->imagelegend($file, $data) if defined($gr->{legend});
  $s .= "</Map>\n";
  unless ($self->{noImgMarkup})
  { $s .= "<Img UseMap=#$name Src=\"$file\" border=0 Height=@{[$gr->{height}]} Width=@{[$gr->{width}]} ";
    map
    { $s .= "$1=".($self->{$_})." " if ($_ =~ /img_(\w*)/i) and defined($self->{$_})
    } keys %{$self};
    chop $s;
    $s .= ">\n";
  } #unless
  return $s;
} #pointsmap

#--------------------------------------------- make map for Bar graph
sub barsmap($$) #($file, \@data)
{ my $self = shift;
  my $file = shift;
  my $data = shift;
  my $gr = $self->{GDGraph};
  my $name = defined $self->{mapName} ? $self->{mapName} : time;
  $gr->check_data($data);
  $gr->setup_coords($data);
  my $s = "<Map Name=$name>\n";
  my $zero = $gr->{zeropoint};
  my $bar_s = _round($gr->{bar_spacing}/2);
  foreach (0 .. $gr->{numpoints})
  { my $bottom = $zero;
    my ($i, $xp, $t);
    my @order = $gr->{overwrite} == 2 ? (1 .. $gr->{numsets}) : reverse(1 .. $gr->{numsets});
    foreach $i (@order)
    { next unless defined($$data[$i][$_]);
      ($xp, $t) = $gr->val_to_pixel($_+1, $$data[$i][$_], $i);
      $s .= "\t<Area Shape=rect Coords=\"";
      if ($gr->{overwrite})
      { my $l = int($xp - _round($gr->{x_step}/2)) + $bar_s;
        my $r = int($xp + _round($gr->{x_step}/2)) - $bar_s;
	$t -= $zero - $bottom if $gr->{overwrite} == 2;
        $s .= ($$data[$i][$_] >= 0) ? "$l, $t, $r, $bottom\" " : "$l, $bottom, $r, $t\" ";
        $bottom = $t - 1;
      } #if
      else
      { my $l = int($xp - $gr->{x_step}/2 + _round(($i-1) * $gr->{x_step}/$gr->{numsets})) + $bar_s;
        my $r = int($xp - $gr->{x_step}/2 + _round($i *  $gr->{x_step}/$gr->{numsets})) - $bar_s;
        $t = int $t;
        $s .= ($$data[$i][$_] >= 0) ? "$l, $t, $r, $zero\" " : "$l, $zero, $r, $t\" ";
      } #else
      my $href = ${$self->{hrefs}}[$i - 1][$_];
      $href = $self->{href} unless defined($href);
      $href =~ s/%x/$data->[0][$_]/g; $href =~ s/%y/$data->[$i][$_]/g;
      $href = $1.(sprintf "%$2f", $data->[0][$_]).$3 if ($href =~ /(^.*)%(\.\d)x(.*$)/);
      $href = $1.(sprintf "%$2f", $data->[$i][$_]).$3 if ($href =~ /(^.*)%(\.\d)y(.*$)/);
      $href =~ s/%l/@{$gr->{legend}}->[$i - 1]/g;
      my $info = $self->{info};
      $info =~ s/%x/$data->[0][$_]/g; $info =~ s/%y/$data->[$i][$_]/g;
      $info = $1.(sprintf "%$2f", $data->[0][$_]).$3 if ($info =~ /(^.*)%(\.\d)x(.*$)/);
      $info = $1.(sprintf "%$2f", $data->[$i][$_]).$3 if ($info =~ /(^.*)%(\.\d)y(.*$)/);
      $info =~ s/%l/@{$gr->{legend}}->[$i - 1]/g;
      $s .= "Href=\"$href\" Title=\"$info\" Alt=\"$info\" onMouseOver=\"window.status=\'$info\'; return true;\" onMouseOut=\"window.status=\'\'; return true;\"";
      if ($self->{newWindow} and not $href =~ /javascript:/i)
      { my $s_;
        map
        { $s_ .= "$1=".$self->{$_}."," if (($_ =~ /window_(\w*)/i) and ($self->{$_} != 0))
        } keys %{$self};
        chop $s_;
        $s .= " Target=_$name";
        $s .= " onClick=\"window.open(\'\', \'_$name\', \'$s_\'); return true;\"";
      } #if
      $s .= ">\n";
    } #foreach
  } #foreach
  $s .= $self->imagelegend($file, $data) if defined($gr->{legend});
  $s .= "</Map>\n";
  unless ($self->{noImgMarkup})
  { $s .= "<Img UseMap=#$name Src=\"$file\" border=0 Height=@{[$gr->{height}]} Width=@{[$gr->{width}]} ";
    map
    { $s .= "$1=".($self->{$_})." " if ($_ =~ /img_(\w*)/i) and defined($self->{$_})
    } keys %{$self};
    chop $s;
    $s .= ">\n";
  } #unless
  return $s;
} #barsmap

#--------------------------------------------- make map for Pie graph
sub piemap($$) #($file, \@data)
{ my $self = shift;
  my $file = shift;
  my $data = shift;
  my $gr = $self->{GDGraph};
  my $name = defined $self->{mapName} ? $self->{mapName} : time;
  $gr->check_data($data);
  $gr->setup_coords();
  my $sum = 0;
  my $i = 0;
  $sum += $data->[1][$i++] while $i <= $gr->{numpoints};
  die "no Total" unless $sum;
  my $pa = $gr->{start_angle};
  my $xc = $gr->{xc};
  my $yc = $gr->{yc};
  my $PI=4*atan2(1, 1);
  my ($pb, $j, $oldj);
  my $s = "<Map Name=$name>\n";
  foreach $i (0 .. $gr->{numpoints})
  { $pb = $pa + 360 * $data->[1][$i] / $sum;
    $s .= "\t<Area Shape=polygon Coords=\"@{[int $xc]}, @{[int $yc]}";
    $oldj = $pa;
    for ($j = $pa; $j < $pb; $j += 10)
    { my $xe = int($xc + $gr->{w} * cos(($ANGLE_OFFSET + $j) * $PI / 180) / 2);
      my $ye = int($yc + $gr->{h} * sin(($ANGLE_OFFSET + $j) * $PI / 180) / 2);
      if ($gr->{'3d'})
      { $s .= ", $xe, $ye" if ($j == $pa and in_front($pa));
        $s .= ", ".$gr->{left}.", ".($ye + $gr->{pie_height}).", ".$gr->{left}.", ".$ye if (($j > 90) and ($oldj < 90));
        $s .= ", ".$gr->{right}.", ".($ye + $gr->{pie_height}).", ".$gr->{right}.", ".$ye if (($j > 270) and ($oldj < 270));
        $s .= in_front($j) ? ", $xe, @{[$ye + $gr->{pie_height}]}" : ", $xe, $ye";
      } #if
      else { $s .= ", $xe, $ye" }
      $oldj = $j;
    } #for
    my $xe = int($xc + $gr->{w} * cos(($ANGLE_OFFSET + $pb) * $PI / 180) / 2);
    my $ye = int($yc + $gr->{h} * sin(($ANGLE_OFFSET + $pb) * $PI / 180) / 2);
    $s .= ", $xe, ".($ye + $gr->{pie_height}) if (in_front($pb) and ($gr->{'3d'}));
    $pa = 100 * $data->[1][$i] / $sum;
    my $href = ${$self->{hrefs}}[$i];
    $href = $self->{href} unless $href;
    $href =~ s/%p/%.0p/g; $href =~ s/%s/$sum/g; $href =~ s/%y/$data->[1][$i]/g;
    $href = $1.(sprintf "%$2f", $pa).$3 if ($href =~ /(^.*)%(\.\d)p(.*$)/);
    $href = $1.(sprintf "%$2f", $sum).$3 if ($href =~ /(^.*)%(\.\d)s(.*$)/);
    $href =~ s/%x/$data->[0][$i]/g;
    $href = $1.(sprintf "%$2f", $data->[1][$i]).$3 if ($href =~ /(^.*)%(\.\d)y(.*$)/);
    my $info = $self->{info};
    $info =~ s/%p/%.0p/g; $info =~ s/%s/$sum/g; $info =~ s/%y/$data->[1][$i]/g;
    $info = $1.(sprintf "%$2f", $pa).$3 if ($info =~ /(^.*)%(\.\d)p(.*$)/);
    $info = $1.(sprintf "%$2f", $sum).$3 if ($info =~ /(^.*)%(\.\d)s(.*$)/);
    $info =~ s/%x/$data->[0][$i]/g;
    $info = $1.(sprintf "%$2f", $data->[1][$i]).$3 if ($info =~ /(^.*)%(\.\d)y(.*$)/);
    $s .= ", $xe, $ye\" Href=\"$href\" Title=\"$info\" Alt=\"$info\" onMouseOver=\"window.status=\'$info\'; return true;\" onMouseOut=\"window.status=\'\'; return true;\"";
    if ($self->{newWindow} and not $href =~ /javascript:/i)
    { my $s_;
      map
      { $s_ .= "$1=".$self->{$_}."," if (($_ =~ /window_(\w*)/i) and ($self->{$_} != 0))
      } keys %{$self};
      chop $s_;
      $s .= " Target=_$name";
      $s .= " onClick=\"window.open(\'\', \'_$name\', \'$s_\')\"; return true;";
    } #if
    $s .= ">\n";
    $pa = $pb;
  } #foreach
  $s .= "</Map>\n";
  unless ($self->{noImgMarkup})
  { $s .= "<Img UseMap=#$name Src=\"$file\" border=0 Height=@{[$gr->{height}]} Width=@{[$gr->{width}]} ";
    map
    { $s .= "$1=".($self->{$_})." " if ($_ =~ /img_(\w*)/i) and defined($self->{$_})
    } keys %{$self};
    chop $s;
    $s .= ">\n";
  } #unless
  return $s;
} #piemap

#--------------------------------------------- private routines used by all objects
sub in_front($) #(angle)
{ my $a = level_angle(shift);
  ($a < $ANGLE_OFFSET or $a > (360 - $ANGLE_OFFSET)) ? 1 : 0;
} #in_front

sub level_angle($) #(angle)
{ my $a = shift;
  return level_angle($a - 360) if $a > 360;
  return level_angle($a + 360) if $a < 0;
  return $a;
} #level_angle

sub imagelegend($$) #($file, \@data)
{ my $self = shift;
  my $file = shift;
  my $data = shift;
  my $gr = $self->{GDGraph};
  my $name = defined $self->{mapName} ? $self->{mapName} : time;
  my $s = '';
  my $xl = $gr->{lg_xs} + $gr->{legend_spacing};
  my $y = $gr->{lg_ys} + $gr->{legend_spacing} - 1;
  my $i = 0;
  my $row = 1;
  my $x = $xl;
  foreach (@{$gr->{legend}})
  { $i++;
    last if ($i > $gr->{numsets});
    my $xe = $x;
    next if (!defined($_) or $_ eq "");
    my $lhref = @{$self->{lhrefs}}->[$i - 1];
    $lhref = $self->{lhref} unless defined($lhref);
    $lhref =~ s/%l/$_/g;
    my $legend = $self->{legend};
    $legend =~ s/%l/$_/g;
    my $ye = $y + int($gr->{lg_el_height}/2 - $gr->{legend_marker_height}/2);
    $s .= "\t<Area Shape=rect Coords=\"$xe, $ye, ".($xe + $gr->{lg_el_width}).", ".($ye + $gr->{legend_marker_height})."\" Href=\"$lhref\" Title=\"$legend\" Alt=\"$legend\" onMouseOver=\"window.status=\'$legend\'; return true;\" onMouseOut=\"window.status=\'\'; return true;\"";
    if ($self->{newWindow} and $lhref ne $self->{href})
    { my $s_;
      map
      { $s_ .= "$1=".$self->{$_}."," if (($_ =~ /window_(\w*)/i) and ($self->{$_} != 0))
      } keys %{$self};
      chop $s_;
      $s .= " Target=_$name";
      $s .= " onClick=\"window.open(\'\', \'_$name\', \'$s_\'); return true;\"";
    } #if
    $s .= ">\n";
    $xe += $gr->{legend_marker_width} + $gr->{legend_spacing};
    my $ys = int($y + $gr->{lg_el_height}/2 - $gr->{lgfh}/2);
    $x += $gr->{lg_el_width};
    if (++$row > $gr->{lg_cols})
    { $row = 1;
      $y += $gr->{lg_el_height};
      $x = $xl;
    } #if
  } #foreach
  return $s;
} #imagelegend

1;

__END__

=head1 NAME

B<GD::Graph::Map> - generate HTML map text for GD::Graph diagramms.

=head1 SYNOPSIS

use GD::Graph::Map;

$map = new GD::Graph::Map($gr_object);

$map->set(key1 => value1, key2 => value2 ...);

$HTML_map = $map->imagemap($gr_file, \@data);

=head1 DESCRIPTION

This is a I<perl5> module to generate HTML map text for following GD::Graph objects
B<GD::Graph::pie>, B<GD::Graph::bars>, B<GD::Graph::lines>, B<GD::Graph::area>,
B<GD::Graph::point> and B<GD::Graph::linespoints>.
As a result of its work is created HTML code containing IMG and MAP tags.
You simply need to insert this code into the necessary place of your HTML page.
In the inserted thus image, its certain parts are the references and at a
choice their mouse in a status line of your browser displays the additional
information (see Samples).

=head1 SAMPLES

See the samples directory in the distribution.

=head1 USAGE

First of all you must create the B<GD::Graph> object and set options if it is necessary.
Then create array of data and use plot routine for create graph image.
For example create B<GD::Graph::pie> object:

  $graph = new GD::Graph::pie;

  $graph->set('title'        => 'A Pie Chart',
              'label'        => 'Label',
              'axislabelclr' => 'black',
              'pie_height'   => 80);

  @data = (["1st","2nd","3rd","4th","5th","6th"],
           [    4,    2,    3,    4,    3,  3.5]);

  $GIFimage = 'Demo.gif';
  open GIF, '>$GIFimage';
  print GIF $graph->plot(\@data)->gif;
  close GIF;

Then create B<GD::Graph::Map> object. And set options using set routine, or set it
in constructor immediately. If it is necessary create hrefs and legend arrays:

  $map = new GD::Graph::Map($graph, newWindow => 1);

  $map->set(info => "%x slice contains %.1p% of %s (%x)");

Create HTML map text using the same array of data as use GD::Graph::plot routine 
and name of the your graph file:

  $HTML_map = $map->imagemap($GIFimage, \@data);

Now you can insert $HTML_map into the necessary place of your HTML page.
You also can create only MAP tag with determined by you map name. For more
information look at noImgMarkup and mapName options of the set routine.

=head1 METHODS AND FUNCTIONS

=over 4

=item Constructor

Constructor of object has following syntax:

  new GD::Graph::Map($gr_object,
    [key1 => value1, key2 => value2 ...]);

where $gr_object this is one of the following graph objects: B<GD::Graph::pie>,
B<GD::Graph::bars>, B<GD::Graph::lines>, B<GD::Graph::area>, B<GD::Graph::point>
or B<GD::Graph::linespoints>; key1, value1 ... the same as using in the set routine.
NOTE: Before use constructor you should at first set all properties for graph object,
because they will be using for generetaing properly HTML map. 

=item imagemap(I<$gr_file>, I<\@data>)

Generate HTML map text using the graph file $file and reference to array
of data - \@data, which must be the same as using in plot routine.

=item set(I<key1> => I<value1>, I<key2> => I<value2> .... )

Set options. See OPTIONS.

=back

=head1 OPTIONS

=over *

=item B<hrefs>, B<lhrefs>

Sets hyper reference for each data (hrefs), and for each legend (lhrefs).
Array @hrefs must the same size as arrays in @data list, otherwise null
elements of @hrefs will set to default. Similarly array @lhrefs must the same
size as the legend array. Default uses the simple JavaScript code 'javascript:;'
instead reference, which do nothing (but in the some browsers it can work incorrectly).

Example of I<@hrefs> array:

for the I<GD::Graph::pie> object:

if     @data  = ([  "1st",  "2nd",  "3rd"],
                 [      4,      2,      3]);

then   @hrefs =  ["1.htm","2.htm","3.htm"];


for the other objects:

if     @data  = ([  "1st",  "2nd",  "3rd"],
                 [      5,     12,     24],
                 [      1,      2,      5]);

then   @hrefs = (["1.htm","2.htm","3.htm"],
                 ["4.htm","5.htm","6.htm"]);

Example of I<@lhrefs> array;

if    @legend = [  'one',  'two','three'];

then  @lhrefs = ["1.htm","2.htm","3.htm"];



=item B<info>, B<legend>

Set information string for the data and for the legend. It will be displayed in the status line
of your browser. Format of this string the same for each data, but you can use special
symbols for receive individual information. Now available following symbols:
I<%x> - Will be replaced on the x values in @data (first array)
I<%y> - Will be replaced on the y values in @data (other arrays)
I<%s> - Will be replaced on the sum of all y values.
I<%l> - Will be replaced on the legend. For all objects, except the B<GD::Graph::pie> object.
I<%p> - Will be replaced on the value, which show what part from all contains this data
(in percentages).

I<%s> and I<%p> symbols can useing only in the B<GD::Graph::pie> object. I<%l> symbol
vice versa available for all objects, except the B<GD::Graph::pie> object. And I<%x>, I<%y>
symbols available for all objects, except the B<GD::Graph::lines> and the B<GD::Graph::area>
objects.
For the numerical parameters (%x, %y, %s and %p) you can use special format
(the same as uses sprintf routine) for round data: %.d{x|y|p|s}, where 'd' is a digit
from 0 to 9.
For example %.0p or %.3x. It is desirable uses if %x, %y, %s or %p is the floating numbers.
Default is 'x=%x y=%y' for info, and '%l' for legend.

=item B<img_*>

You can set any attribute in the IMG tag (except UseMap, Src, Width, Height and Border,
they will be set automatically) use set routine: set(img_option => value), where 'option'
is the IMG attribute. For instance: routine set(img_Alt => 'Example') will include Alt='Example'
in the IMG tag.

=item B<newWindow>, B<window_*>

If the newWindow attribute is set to the TRUE and link does not contains JavaScript code
(like javascript:), that link will be open in the new navigator window. Parameters of the
new window you can establish using the window_* parameters, similarly the img_*.

=item B<mapName>

If mapName is TRUE the map will have this name. Default is time().

=item B<noImgMarkup>

If noImgMarkup is TRUE will be printed only the MAP tag, without
the <Img UseMap=... > markup. You will have to print your own.
Useful if the Graph is generated and poured directly to the a
web-browser and not plotted to a GIF file.

=back

=head1 AUTHOR

Roman Kosenko

=head2 Contact info

E-mail:    ra@amk.lg.ua

Home page: http://amk.lg.ua/~ra/Map

=head2 Copyright

Copyright (C) 1999-2000 Roman Kosenko.
All rights reserved.  This package is free software;
you can redistribute it and/or modify it under the same
terms as Perl itself.

