package Rose::DB::Object::Metadata::Column::Timestamp;

use strict;

use Rose::DateTime::Util;
use Rose::DB::Object::MakeMethods::Date;

use Rose::DB::Object::Metadata::Column::Date;
our @ISA = qw(Rose::DB::Object::Metadata::Column::Date);

our $VERSION = '0.02';

sub type { 'timestamp' }

sub method_maker_class { 'Rose::DB::Object::MakeMethods::Date' }
sub method_maker_type  { 'timestamp' }

sub should_inline_value
{
  #my($self, $db, $value) = @_;
  return ($_[1]->validate_timestamp_keyword($_[2]) && 
          ($_[1]->driver eq 'Informix' || $_[2] =~ /^\w+\(.*\)$/)) ? 1 : 0;
}

sub parse_value
{
  shift; 
  my $db = shift;
  my $dt = $db->parse_timestamp(@_);
  
  unless($dt)
  {
    $dt = Rose::DateTime::Util::parse_date($_[0], $db->server_time_zone)
  }
  
  return $dt;
}

sub format_value { shift; shift->format_timestamp(@_) }

1;

__END__

=head1 NAME

Rose::DB::Object::Metadata::Column::Timestamp - Timestamp column metadata.

=head1 SYNOPSIS

  use Rose::DB::Object::Metadata::Column::Timestamp;

  $col = Rose::DB::Object::Metadata::Column::Timestamp->new(...);
  $col->make_method(...);
  ...

=head1 DESCRIPTION

Objects of this class store and manipulate metadata for timestamp columns in a database.  Column metadata objects store information about columns (data type, size, etc.) and are responsible for creating object methods that manipulate column values.

This class inherits from L<Rose::DB::Object::Metadata::Date>. Inherited methods that are not overridden will not be documented a second time here.  See the L<Rose::DB::Object::Metadata::Date> documentation for more information.

=head1 OBJECT METHODS

=over 4

=item B<method_maker_class>

Returns L<Rose::DB::Object::MakeMethods::Date>.

=item B<method_maker_type>

Returns C<timestamp>.

=item B<parse_value DB, VALUE>

Convert VALUE to the equivalent C<DateTime> object.  VALUE maybe returned unmodified if it is a valid timestamp keyword or otherwise has special meaning to the underlying database.  DB is a L<Rose::DB> object that is used as part of the parsing process.  Both arguments are required.

=item B<type>

Returns "timestamp".

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
