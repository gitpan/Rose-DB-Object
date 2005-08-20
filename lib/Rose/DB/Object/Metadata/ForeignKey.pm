package Rose::DB::Object::Metadata::ForeignKey;

use strict;

use Rose::DB::Object::Metadata::Util qw(:all);

use Rose::DB::Object::Metadata::Column;
our @ISA = qw(Rose::DB::Object::Metadata::Column);

our $VERSION = '0.02';

use overload
(
  # "Undo" inherited overloaded stringification.  
  # (Using "no overload ..." didn't seem to work.)
  '""' => sub { overload::StrVal($_[0]) },
   fallback => 1,
);

__PACKAGE__->add_method_maker_argument_names
(
  qw(share_db class key_columns)
);

use Rose::Object::MakeMethods::Generic
(
  boolean =>
  [
    'share_db' => { default => 1 },
  ],

  hash =>
  [
    key_column  => { hash_key  => 'key_columns' },
    key_columns => { interface => 'get_set_all' },
  ],
);

Rose::Object::MakeMethods::Generic->make_methods
(
  { preserve_existing => 1 },
  scalar => [ __PACKAGE__->method_maker_argument_names ],
);

sub method_maker_class { 'Rose::DB::Object::MakeMethods::Generic' }
sub method_maker_type  { 'object_by_key' }

sub type { 'foreign key' }

sub id
{
  my($self) = shift;

  my $key_columns = $self->key_columns;

  return $self->class . ' ' . 
    join("\0", map { join("\1", lc $_, lc $key_columns->{$_}) } sort keys %$key_columns);
}

sub perl_hash_definition
{
  my($self, %args) = @_;

  my $meta = $self->parent;

  my $indent = defined $args{'indent'} ? $args{'indent'} : 
                 ($meta ? $meta->default_perl_indent : undef);

  my $braces = defined $args{'braces'} ? $args{'braces'} : 
                 ($meta ? $meta->default_perl_braces : undef);

  my $indent_txt = ' ' x $indent;

  my $def = perl_quote_key($self->name) . ' => ' .
            ($braces eq 'bsd' ? "\n{\n" : "{\n") .
            $indent_txt . 'class => ' . perl_quote_value($self->class) . ",\n";

  my $key_columns = $self->key_columns;

  my $max_len = 0;
  my $min_len = -1;

  foreach my $name (keys %$key_columns)
  {
    $max_len = length($name)  if(length $name > $max_len);
    $min_len = length($name)  if(length $name < $min_len || $min_len < 0);
  }

  $def .= $indent_txt . 'key_columns => ' . ($braces eq 'bsd' ? "\n" : '');

  my $hash = perl_hashref(hash => $key_columns, indent => $indent * 2, inline => 0);

  for($hash)
  {
    s/^/$indent_txt/g;
    s/\A$indent_txt//;
    s/\}\Z/$indent_txt}/;
    s/\A(\s*\{)/$indent_txt$1/  if($braces eq 'bsd');
  }

  $def .= $hash . ",\n}";

  return $def;
}

1;

__END__

=head1 NAME

Rose::DB::Object::Metadata::ForeignKey - Foreign key metadata.

=head1 SYNOPSIS

  use Rose::DB::Object::Metadata::ForeignKey;

  $fk = Rose::DB::Object::Metadata::ForeignKey->new(...);
  $fk->make_method(...);
  ...

=head1 DESCRIPTION

Objects of this class store and manipulate metadata for foreign keys in a database table.  It stores information about which columns in the local table map to which columns in the foreign table, and is responsible for creating an accessor method for the foreign object.

This class represents (and will create an accessor method for) C<the thing referenced by> the foreign key column(s).  You'll still need accessor method(s) for the foreign key column(s) themselves.

Both the local table and the foreign table will need L<Rose::DB::Object>-derived classes fronting them.

Since there is a lot of overlap in responsibilities, this class inherits from L<Rose::DB::Object::Metadata::Column>. Inherited methods that are not overridden will not be documented a second time here.  See the L<Rose::DB::Object::Metadata::Column> documentation for more information.

=head1 OBJECT METHODS

=over 4

=item B<class [CLASS]>

Get or set the class name of the L<Rose::DB::Object>-derived object that encapsulates rows from the table referenced by the foreign key column(s).

=item B<key_column LOCAL [, FOREIGN]>

If passed a local column name LOCAL, return the corresponding column name in the foreign table.  If passed both a local column name LOCAL and a foreign column name FOREIGN, set the local/foreign mapping and return the foreign column name.

=item B<key_columns [HASH | HASHREF]>

Get or set a reference to a hash that maps local column names to foreign column names in the table referenced by the foreign key.

=item B<make_method PARAMS>

Create an object method used to fetch the L<Rose::DB::Object>-derived object referred to by the foreign key.  To do this, the C<make_methods()> class method of the L<method_maker_class> is called.  PARAMS are name/value pairs.  Valid PARAMS are:

=over 4

=item C<options HASHREF>

A reference to a hash of options that will be passed as the first argument to the call to the C<make_methods()> class method of the L<method_maker_class>.  This parameter is required, and the HASHREF must include a value for the key C<target_class>, which C<make_methods()> needs in order to determine where to make the method.

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

The L<method_maker_class> is expected to be a subclass of (or otherwise conform to the interface of) L<Rose::Object::MakeMethods>.  See the L<Rose::Object::MakeMethods> documentation for more information on the interface, and the C<make_methods()> method in particular.

More than one method may be created, but there must be at least one accessor method created, and its name must match the L<method_name> (or L<name> if L<method_name> is undefined).

=item B<method_maker_class>

Returns L<Rose::DB::Object::MakeMethods::Generic>.

=item B<method_maker_type>

Returns C<object_by_key>.

=item B<method_name [NAME]>

Get or set the name of the object method to be created for this foreign key.  This may be left undefined if the desired method name is stored in L<name> instead.  Once the method is actually created, the L<method_name> will be set.

=item B<name [NAME]>

Get or set the name of the foreign key.  This name must be unique among all other foreign keys for a given L<Rose::DB::Object>-derived class.

=item B<share_db [BOOL]>

Get or set the boolean flag that determines whether the C<db> attribute of the current object is shared with the foreign object to be fetched.  The default value is true.

=item B<type>

Returns "foreign key".

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
