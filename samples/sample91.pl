use GD::Graph::pie;
use GD::Graph::Map;

print STDERR "Processing sample 9-1\n";

@data = ( 
    ["1st","2nd","3rd","4th","5th","6th"],
    [    4,    2,    3,    4,    3,  3.5]
);

$my_graph = new GD::Graph::pie();

$my_graph->set( 
	title => 'A Pie Chart',
	label => 'Label',
	axislabelclr => 'black',
	pie_height => 70,
);

open GIF, ">sample91.gif";
print GIF $my_graph->plot(\@data)->gif;
close GIF;

$map = new GD::Graph::Map($my_graph, info => '%x: %y (%p%)');

open HTML, ">sample91.html";
print HTML "<HTML><BODY>\n".
  ($map->imagemap("sample91.gif", \@data)).
  "</BODY></HTML>";
close HTML;

__END__
