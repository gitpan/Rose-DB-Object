package Rose::DB::Object::Metadata::Column::DatetimeYearToMinute;

use strict;

use Rose::DB::Object::Metadata::Column::Datetime;
our @ISA = qw(Rose::DB::Object::Metadata::Column::Datetime);

our $VERSION = '0.01';

sub type { 'datetime year to minute' }

sub should_inline_value
{
  #my($self, $db, $value) = @_;
  return ($_[1]->validate_datetime_year_to_minute_keyword($_[2]) && 
          ($_[1]->driver eq 'Informix' || $_[2] =~ /^\w+\(.*\)$/)) ? 1 : 0;
}

1;

__END__

=head1 NAME

Rose::DB::Object::Metadata::Column::DatetimeYearToMinute - Datetime year to minute column metadata.

=head1 SYNOPSIS

  use Rose::DB::Object::Metadata::Column::DatetimeYearToMinute;

  $col = 
    Rose::DB::Object::Metadata::Column::DatetimeYearToMinute->new(...);

  $col->make_method(...);
  ...

=head1 DESCRIPTION

Objects of this class store and manipulate metadata for "datetime year to minute  columns" in a database.  Column metadata objects store information about columns (data type, size, etc.) and are responsible for creating object methods that manipulate column values.

This class inherits from C<Rose::DB::Object::Metadata::Datetime>. Inherited methods that are not overridden will not be documented a second time here.  See the C<Rose::DB::Object::Metadata::Datetime> documentation for more information.

=head1 OBJECT METHODS

=over 4

=item B<method_maker_class>

Returns C<Rose::DB::Object::MakeMethods::Date>.

=item B<method_maker_type>

Returns C<datetime>.

=item B<type>

Returns "datetime year to minute".

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
