#!/usr/bin/perl
use Tk;
use Tk::Table;
use Tk::DragDrop;
use Tk::DropSite;
use Tk::DialogBox;
use Tk::Entry;
use DateTime;
use IPC::Run qw/run timeout/;
use Data::Dumper;
use JSON;
use warnings;
use strict;

my $json = JSON->new();

my ($ButtonClr, $ListClr, $DfltClr) = ("SkyBlue1", "LightSkyBlue2", "#d9d9d9");
my ($rows, $marker_repeat) = (5, 4);
my $font3 = '-*-fixed-*-*-*-*-*-140-*-*-*-*-*-*';
my ($rdgel_ref, $user_id, $session_id, $source, @clones, @enzymes, @reqs,
    @lbls, @drops, $method);
my $changed = 0;
my %actions = ();

my @buttons = qw/Blue Purple Green Orange/;

#
# Create a main window with a listbox, a table and some buttons
#

my $w = MainWindow->new();
$w->title("Dog Buttons");
$w->iconname("Dog Buttons");
my $w_buttons = $w->Frame;
$w->Label(-text => "Drag action from list to specific button " .
	  "")
    ->pack(-side => 'bottom');
my $tf = $w->Frame->pack(-side => 'right');
my $table = $tf->Table(-rows => 6,
		      -columns => 2,
		      -scrollbars => '',
		      -fixedrows => 1,
		      -fixedcolumns => 1,
		      -takefocus => 1,
		     );
$table->pack(-side => 'top', -fill => 'both');
#my $geltitle = $tf->Label(-relief => 'raised')->pack(-side => 'top', -fill => 'x');
$w_buttons->pack(qw(-side bottom -fill x -pady 0.5m));

foreach my $name (@buttons) {
  $tf->Button(
      -background => $name,
      -text    => $name,
      -command => [\&Button, $name],
      -padx => 40,
      -pady => 20,
      )->pack(qw(-side left -expand 1));
}
$method = 'variable';

my $addCmd;
$w_buttons->Button(
  -background => $ButtonClr,
  -text => "Add Action",
  -command => [\&AddAction],
  -padx => 5,
  -pady => 5,
  )->pack(qw/-side left -expand 1 -fill both/);
$w_buttons->Entry(
  -textvariable => \$addCmd,
  -width => 60,
)->pack(qw/-side left -expand 1 -fill both/);

#my $w_entry = $w_buttons->Entry(
#    -width=>1,
#    -takefocus=>1,
#  )->pack(qw/-side right/);

my $aw = $w->Frame->pack(qw(-side bottom));
$aw->Label(-text => "Available Actions")->pack(-side => 'top',
						  -fill => 'x');
my $lb = $aw->Listbox(-height => 10, -width => 62,
		      -background => $DfltClr, -font => $font3);
$lb->pack(-side => 'left', -fill => 'y');
my $awsb = $aw->Scrollbar(-command => [$lb => 'yview']);
$awsb->pack(-side => 'right', -fill => 'y');
$lb->configure(-yscrollcommand => [$awsb => 'set']);

#
# Make the listbox a Drag and Drop source, but disable this for now by
# binding -startcommand to a routine which does nothing but return true
# (indicating that it has handled the Drag initialisation itself)
#
# The last 3 parameters to the DragDrop invocation are (mutually exclusive)
# alternatives, the commented-out versions allow fixed text or a fixed image
# to be displayed in the Drag window, whilst defining a -startcommand callback
# allows us to choose the text on the fly and show visually exactly what is
# being dragged.
#

$source = $lb->DragDrop(-event => '<B1-Motion>',
			-sitetypes => [qw(Local)],
			-handlers => [[\&send_string],
				      [-type => 'FILE_NAME',
				       \&send_file]],
			-startcommand => [\&DragInhibit],
#			-image => $image,    #use an image, not text
#			-text => "this is it", #fixed text string
			);


#
# Generate a bitmap for use with Drag and Drop.
#

my $image = $w->Bitmap('win', # -file => 'win.xbm'
		       -data => "#define win.xbm_width 16
#define win.xbm_height 16
static char win.xbm_bits[] = {
   0xff, 0xff, 0x0d, 0xb0, 0xff, 0xff, 0x01, 0x80, 0x01, 0x80, 0x01, 0x80,
   0x01, 0x80, 0x01, 0x80, 0x01, 0x80, 0x01, 0x80, 0x01, 0x80, 0x01, 0x80,
   0x01, 0x80, 0x01, 0x80, 0x01, 0x80, 0xff, 0xff};
");

sub saveConf {
    my @a = $lb->get(0, $lb->size);

    my $file = $ENV{HOME}."/.k9buttons.json";
    open FILE, ">", $file || die "cannot write to conf $file. $!";
    my $conf = {
      actions => \@a,
      buttons => \%actions
    };
    print Dumper(\$conf);
    print FILE $json->encode($conf)."\n";
    close FILE;
}
sub loadConf {
    local $/;
    $/ = undef;
    my $name = $ENV{HOME}."/.k9buttons.json";
    my $conf = undef;
    if (-e $name) {
      open FILE, "<", $name || die "cannot open conf \"$name\": $!";
      my $file = <FILE>;
      close FILE;
      $conf = $json->decode($file);
    }
    foreach my $name (keys %{$conf->{buttons}}) {

      $actions{$name} = $conf->{buttons}->{$name};
    }
    return $conf;
}

sub AddAction {
    print "command [$addCmd]\n"; 
    $lb->insert('end',$addCmd);
    saveConf();
    $addCmd = "";
};

{
  my ($then);
sub keysym { 
  my($widget) = @_;
  my $e = $widget->XEvent;
# get event object 
  my($keysym_text, $keysym_decimal) = ($e->K, $e->N); 
  my $sn = '#';
#  print "[".$e->$sn."]";
#  printf("keysym=$keysym_text, numeric=$keysym_decimal, time=%s\n", $e->t);

  my %map = (
      52 => $buttons[0],
      57 => $buttons[1],
      91 => $buttons[2],
      32 => $buttons[3],
      );
  if (exists $map{$keysym_decimal}) {
    my $btn = $map{$keysym_decimal};
    if (defined $then) {
      my $elapsed = $e->t - $then;
      if ($elapsed > 500) {
      print "elapsed $elapsed\n";
        Button($btn);
      }
    } else {
      Button($btn);
    }
    $then = $e->t;
  }
}
}
$w->bind('<KeyPress>' => \&keysym); 
 #docstore.mik.ua/orelly/perl3/tk/ch15_02.htm

#
# Populate the table and listbox
#

BuildTable();
Fill_lb();

#	$source->configure(-image => 'win');
#	$source->configure(-startcommand => \&DragOK);


#
# Let the user interact
#

MainLoop();

######################################################################
#
# End of main program, start of subroutines
#
#

#
# Put some data into the listbox so that it can be dragged and dropped
#

sub Fill_lb {
    $lb->delete('0','end');

    my $conf = loadConf();
    print Dumper(\$conf);
    if (defined $conf) {
      my @data = @{$conf->{actions}};
      $lb->insert('end',@data);
    }
}

#
# Populate the rows and columns of the table. Inactive (marker) rows just have
# a label; remainder have a label (which will become a dropsite) plus two
# readonly text-entry fields to display the dropped data
#

sub BuildTable {
    my ($row,$name);

    $table->put(0, 1, $table->Label(-text => "Button Map of Actions",
				    -relief => 'raised',
				    -width => 15));

    $row = 0;
    foreach $name (@buttons) {
      print "$name\n";
	    my $lbl = $table->Label(-text => "$name",
				    -relief => 'sunken',
            -background => $name,
            -padx => 10,
            -pady => 10
				    );
	    $lbls[$row] = $lbl;
	    $table->put($row + 1,0,$lbl);
	    my $centry = $table->Entry(-width => 60,
				       -textvariable => \$actions{$name},
				       -state => 'disabled');
	    $table->put($row + 1,1,$centry);
      $row++;
    }
$source->configure(-startcommand => [\&DragSetup, $lb]);
$source->configure(-image => undef);

    $lb->configure(-background => $ListClr);
    my $i = 0;
    foreach my $name (@buttons) {
#	    $lbls[$i]->configure(-background => $ButtonClr);
	    $drops[$i] = $lbls[$i]->DropSite(-droptypes => [qw(Local)],
			   -dropcommand => [\&Dropit,$i, $name],
			   -entercommand => [\&SiteEntry, $lbls[$i]],
			   );
      $i++;
    }
}

#
# Make active Dropsites respond (by changing their relief) when dragged object
# passes over them
#

sub SiteEntry {
    my ($lbl, $entry, @data) = @_;
    $lbl->configure(-relief => $entry == 1 ? 'raised' : 'sunken');
}

#
# This handler would be invoked if our drop handler specified FILE_NAME as
# the data type. Not used here, but included for illustration.
#

sub send_file {
     my ($offset,$max) = @_;

     return __FILE__;
}

#
# get current selection from listbox and return it to dropsite
#

sub send_string
{
 my ($offset,$max) = @_;
    my ($lb_sel) = $lb->curselection;
    my ($req) = $lb->get($lb_sel);
 return $req;
}

#
# Handle a drop - get dragged text, break into components and place in arrays
# to be displayed in table, delete source from listbox, kill the dropsite and
# make its colour revert to default.
#

sub Dropit {
    my ($row,$name,$seln) = @_;
    print "$row  $seln\n";
    my ($rdreq) = $lb->SelectionGet('-selection'=>$seln,'STRING');
    print "$rdreq\n";
    my ($clone, $enz) = split " ", $rdreq;
#   $clones[$row] = $rdreq;
    $enzymes[$row] = $enz;
    my ($lb_sel) = $lb->curselection;
    $lb->delete($lb_sel);
    $lb->selectionSet($lb_sel);
    $reqs[$row] = $rdreq;
    $actions{$name} = $rdreq;
    $drops[$row]->delete;
#    $lbls[$row]->configure(-bg => $DfltClr);
    $changed = 1;
    saveConf();
    $w->focus;
}

sub Button {
  my ($name) = @_;
  print "$name\t";
  my $cmd = $actions{$name};
  if (defined $cmd) {
    print "$cmd";
    print "\n";
    my @cmd = split " ", $cmd;
    my ($in, $out, $err);
    run \@cmd, \$in, \$out, \$err, timeout( 10 ) or die "cmd [$cmd]: $?";
    print "$out\n";
    print "$err\n";

  } else {
    print "\n";
  }
}

#
# Disable Dragging by pretending that we've handled the initialisation
# of the drag window ourselves
#

sub DragInhibit {
    return 1;
}

#
# Enable dragging by asking the DragDrop object to initialise it for us
#

sub DragOK {
    return 0;
}

#
# Make the drag window show the text of what's being transferred
#
# Caution advised here in case we turn out to be dragging 2K of text!
#
# Returns 0 to indicate that the drag initialisation still needs to be
# handled by the source object.

sub DragSetup {
    my ($lb) = @_;

    my ($lb_sel) = $lb->curselection;
    my ($row) = $lb->get($lb_sel);
    my ($clone, $enzyme) = split " ", $row;
    my $text = sprintf "%s/%s", $clone, $enzyme;
    $source->configure(-text => $text);

    return 0;
}


#
# Clean up and quit
#

sub Done {
    exit 0;
}

END {

}

__END__
=head1 NAME
DragDrop - create and manipulate widgets whose selections can be dragged and dropped
DropSite - create and manipulate DropSites for Dragged selections
=head1 SYNOPSIS
    use Tk::DragDrop;
    use Tk::DropSite;
    $source = $widget->DragDrop(-event => '<Event>',
				-sitetypes => ['Local'],
				-handlers => [[\&callback],
					      [-type => 'TYPENAME',
					        \&callback]],
			        );
    $drop = $widget->DropSite(-droptypes => ['Local'],
			      -dropcommand => [\&Dropit,?params?],
			      );
=head1 DESCRIPTION
B<NB> This is unofficial documentation, believed to be correct but neither
complete not definitive. B<Caveat programmer!>
B<DragDrop> implements drag-and-drop for Tk apps. It should work on
any platform for local (within one application) droptypes, but only the Sun
interface is defined for global (interapplication) droptypes.
User can drag objects with the mouse (Button-1 by default) from
DragDrop sources, and drop them on DropSites. By default, pressing any key
during the Drag operation will abort it. There is support for different
types of information transfer (eg STRING, ATOM, INTEGER - see Tk::Selection
and/or the X Inter-Client Communication Conventions Manual (ICCCM)
for details) and also user-defined types (eg FILE_NAME in the example
code below) via user-defined handlers.
Local (intra-application) transfer is via the X Selection mechanism. Global
(interapplication) transfer uses the Sun protocols defined in the
Tk::DragDrop::Sunconstant module.
=head2 Example Code
 use Tk;
 use Tk::DragDrop;
 use Tk::DropSite;
 @data = ('One','Two','Three', 'Four');
 $w = MainWindow->new();
 $lb = $w->Listbox->pack;
 $lb->insert('end', @data);
 $lab = $w->Label(-text => "Drop here!")->pack;
 $source = $lb->DragDrop(-event => '<B1-Motion>',
			 -sitetypes => [qw(Local)],
			 -handlers => [[\&send_string],
				       [-type => 'FILE_NAME',
					\&send_file]]);
 $drop = $lab->DropSite(-droptypes => [qw(Local)],
			-dropcommand => [\&Dropit, $lb],
			-entercommand => [\&SiteEntry, $lab],
			);
 MainLoop();
 sub send_file {
     my ($offset,$max) = @_;
     return __FILE__;
 }
 sub send_string {
    my ($offset,$max) = @_;
    my ($lb_sel) = $lb->curselection;
    my ($req) = $lb->get($lb_sel);
    return $req;
 }
 sub Dropit {
    my ($lb,$seln) = @_;
    my ($req) = $lb->SelectionGet('-selection'=>$seln,'STRING');
    print "$req\n";
 }
 sub SiteEntry {
     my ($w, $entry, @data) = @_;
     $w->configure(-relief => $entry == 1 ? 'raised' : 'sunken');
 }
=head1 CONFIGURATION
The non-standard options recognised by B<DragDrop> are as follows:-
=over 4
=item B<-event>
The event which will initiate dragging.
=item B<-sitetypes>
Whether the applications served by this source will be local ('local'),
global ('Sun') or both (I<undef>).
=item B<-handlers>
Handler routines for each supported type of data to be
transferred
=item B<-image>
Optionally a (bitmap) image to display instead of text when an
item is being dragged.
=item B<-startcommand>
Optionally a callback invoked before dragging is initiated. Subroutine
(which is called without any parameters) must return 0 if Drag is to be
allowed, otherwise the event will be ignored. Defaults to I<undef>.
=item B<-predropcommand>
Optionally a callback invoked before dropping occurs. Subroutine
(which will be called with the source application ID string and the
dropsite widget as parameters) must return 0 if Drop is allowed,
otherwise no handler is called. Defaults to I<undef>.
=item B<-postdropcommand>
Optionally a callback invoked after dropping occurs. Subroutine will
be called with the source application ID string and need not return
any specific value. Defaults to I<undef>.
=item B<-cursor>
Optionally the cursor to use whilst dragging. Defaults to 'hand2'
=item B<-text>
Optionally some fixed text to display in the drag window.
Defaults to the classname of the parent widget.
=back
The non-standard options recognised by B<DropSite> are as follows:-
=over 4
=item B<-droptypes>
Whether items will be dropped from local ('local'), global ('Sun')
or both (I<undef>) applications
=item B<-dropcommand>
Callback subroutine to invoke when something is dropped here
=item B<-entercommand>
Optionally, callback routine to invoke whenever dragged object
enters or leaves the DropSite. Defaults to I<undef>.
=back
=head1 METHODS
B<DragDrop> supports the following methods:-
B<DropSite> supports the following methods:-
=over 4
=item B<-delete>
Remove this object from the list of registered DropSites
=back
=head1 DEFAULT BINDINGS
=over 4
When the window representing the dragged object is mapped,
the Mapped method is called (class binding).
Any button motion invokes the Drag method (class binding).
Any button release invokes the Drop method (class binding).
Any keypress whilst dragging invokes the Done method,
aborting the drag (class binding).
Button 1 invokes the StartDrag method (instance binding).
=back
=head1 BUGS
There is currently no way a DragDrop source can remove an event
binding once it has been installed (however this can be done
manually by removing the binding from the parent widget).
Destroying a DragDrop source doesn't remove the binding from the
parent widget, causing Tk to complain if the bound callback is
later invoked.
DropSites can't be within a scrolling Table (this is a Table bug,
not a DragDrop one).
=head1 AUTHORS
B<Nick Ing-Simmons> nik@tiuk.ti.com : Original module code
B<John Attwood> ja1@sanger.ac.uk    : This demo and draft pod docs
=cut

