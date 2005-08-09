package Rose::DB::Object::Metadata::Column::DatetimeYearToFraction2;

use strict;

use Rose::DB::Object::Metadata::Column::DatetimeYearToFraction;
our @ISA = qw(Rose::DB::Object::Metadata::Column::DatetimeYearToFraction);

our $VERSION = '0.01';

sub type { 'datetime year to fraction(2)' }

sub format_value { shift; shift->format_datetime_year_to_fraction_5(@_) }

1;

__END__

=head1 NAME

Rose::DB::Object::Metadata::Column::DatetimeYearToFraction2 - Datetime year to fraction(2) column metadata.

=head1 SYNOPSIS

  use Rose::DB::Object::Metadata::Column::DatetimeYearToFraction2;

  $col = 
    Rose::DB::Object::Metadata::Column::DatetimeYearToFraction2->new(...);

  $col->make_method(...);
  ...

=head1 DESCRIPTION

Objects of this class store and manipulate metadata for "datetime year to fraction(2)" columns in a database.  Column metadata objects store information about columns (data type, size, etc.) and are responsible for creating object methods that manipulate column values.

This class inherits from L<Rose::DB::Object::Metadata::Datetime>. Inherited methods that are not overridden will not be documented a second time here.  See the L<Rose::DB::Object::Metadata::Datetime> documentation for more information.

=head1 OBJECT METHODS

=over 4

=item B<method_maker_class>

Returns L<Rose::DB::Object::MakeMethods::Date>.

=item B<method_maker_type>

Returns C<datetime>.

=item B<parse_value DB, VALUE>

Convert VALUE to the equivalent C<DateTime> object suitable for storage in a "datetime year to fraction(2)" column.  VALUE maybe returned unmodified if it is a valid "datetime year to fraction(2)" keyword or otherwise has special meaning to the underlying database.  DB is a L<Rose::DB> object that is used as part of the parsing process.  Both arguments are required.

=item B<type>

Returns "datetime year to fraction(2)".

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.