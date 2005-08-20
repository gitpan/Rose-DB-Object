package Rose::DB::Object::Metadata::Relationship;

use strict;

use Carp();

use Rose::DB::Object::Metadata::MethodMaker;
our @ISA = qw(Rose::DB::Object::Metadata::MethodMaker);

our $VERSION = '0.01';

Rose::Object::MakeMethods::Generic->make_methods
(
  { preserve_existing => 1 },
  scalar => 
  [
    __PACKAGE__->method_maker_argument_names,
  ],
);

sub type { die "Override in subclass" }

sub method_maker_class { die "Override in subclass" }
sub method_maker_type  { die "Override in subclass" }

1;

__END__

=head1 NAME

Rose::DB::Object::Metadata::Relationship - Base class for table relationship metadata objects.

=head1 SYNOPSIS

  package MyRelationshipType;

  use Rose::DB::Object::Metadata::Relationship;
  our @ISA = qw(Rose::DB::Object::Metadata::Relationship);
  ...

=head1 DESCRIPTION

This is the base class for objects that store and manipulate database table relationship metadata.  Relationship metadata objects are responsible for creating object methods that fetch and/or manipulate objects from foreign tables.  See the L<Rose::DB::Object::Metadata> documentation for more information.

=head1 CONSTRUCTOR

=over 4

=item B<new PARAMS>

Constructs a new object based on PARAMS, where PARAMS are
name/value pairs.  Any object method is a valid parameter name.

=back

=head1 OBJECT METHODS

=over 4

=item B<class [CLASS]>

Get or set the name of the L<Rose::DB::Object>-derived class that fronts the foreign table referenced by this relationship.

=item B<make_method PARAMS>

Create an object method used to fetch and/or manipulate objects from foreign tables.  To do this, the C<make_methods()> class method of the L<method_maker_class|/method_maker_class> is called.  PARAMS are name/value pairs.  Valid PARAMS are:

=over 4

=item C<options HASHREF>

A reference to a hash of options that will be passed as the first argument to the call to the C<make_methods()> class method of the L<method_maker_class|/method_maker_class>.  This parameter is required, and the HASHREF must include a value for the key C<target_class>, which C<make_methods()> needs in order to determine where to make the method.

=back

The call to C<make_methods()> looks something like this:

    my $method_name = $self->method_name;

    # Use "name" if "method_name" is undefined
    unless(defined $method_name)
    {
      # ...and set "method_name" so it's defined now
      $method_name = $self->method_name($self->name);
    }

    $self->method_maker_class->make_methods(
      $args{'options'}, 
      $self->method_maker_type => 
      [
        $method_name => scalar $self->method_maker_arguments
      ]);

where C<$args{'options'}> is the value of the "options" PARAM.

The L<method_maker_class|/method_maker_class> is expected to be a subclass of (or otherwise conform to the interface of) L<Rose::Object::MakeMethods>.  See the L<Rose::Object::MakeMethods> documentation for more information on the interface, and the C<make_methods()> method in particular.

More than one method may be created, but there must be at least one method created, and its name must match the L<method_name|/method_name> (or L<name|/name> if L<method_name|/method_name> is undefined).

=item B<method_maker_arguments>

Returns a hash (in list context) or a reference to a hash (in scalar context) or arguments that will be passed (as a hash ref) to the call to the C<make_methods()> class method of the L<method_maker_class|/method_maker_class>, as shown in the L<make_method|/make_method> example above.

The default implementation populates the hash with the defined return values of the object methods named by L<method_maker_argument_names|/method_maker_argument_names>.  (Method names that return undefined values are not included in the hash.)

=item B<method_maker_argument_names>

Returns a list of methods to call in order to generate the L<method_maker_arguments|/method_maker_arguments> hash.

=item B<method_maker_class>

Returns the name of the L<Rose::Object::MakeMethods>-derived class used to create the object method that will fetch and/or manipulate objects from foreign tables.  You must override this method in your subclass.  The default implementation causes a fatal error if called.

=item B<method_maker_type>

Returns the method type, which is passed to the call to the C<make_methods()> class method of the L<method_maker_class|/method_maker_class>, as shown in the L<make_method|/make_method> example above.  You must override this method in your subclass.  The default implementation causes a fatal error if called.

=item B<method_name [NAME]>

Get or set the name of the object method to be created for this relationship.  This may be left undefined if the desired method name is stored in L<name|/name> instead.  Once the method is actually created, the L<method_name|/method_name> will be set.

=item B<name [NAME]>

Get or set the name of the relationship.  This name must be unique among all other relationships for a given L<Rose::DB::Object>-derived class.

=item B<type>

Returns a string describing the type of relationship.  You must override this method in your subclass.  The default implementation causes a fatal error if called.

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
