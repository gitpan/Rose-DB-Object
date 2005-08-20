package Rose::DB::Object::Metadata::MethodMaker;

use strict;

use Rose::DB::Object::Metadata::Object;
our @ISA = qw(Rose::DB::Object::Metadata::Object);

our $VERSION = '0.01';

use Rose::Class::MakeMethods::Set
(
  inherited_set => 'method_maker_argument_name'
);

Rose::Object::MakeMethods::Generic->make_methods
(
  { preserve_existing => 1 },
  scalar => 
  [
    'name',
    'method_name',
    __PACKAGE__->method_maker_argument_names,
  ],
);

sub method_maker_arguments
{
  my($self) = shift;

  my %opts = map { $_ => scalar $self->$_() } grep { defined scalar $self->$_() }
    $self->method_maker_argument_names;

  return wantarray ? %opts : \%opts;
}

sub method_maker_class { die "Override in subclass" }
sub method_maker_type  { die "Override in subclass" }

sub make_method
{
  my($self, %args) = @_;

  Carp::croak "Missing required 'options' argument"
    unless($args{'options'});

  Carp::croak "Missing required 'target_class' argument"
    unless($args{'options'}{'target_class'});

  my $method_name = $self->method_name;

  unless(defined $method_name)
  {
    $method_name = $self->method_name($self->name);
  }

  $self->method_maker_class->make_methods(
    $args{'options'}, 
    $self->method_maker_type => 
    [
      $method_name => { column => $self, $self->method_maker_arguments }
    ]);
}

1;
