package Rose::DB::Objects::Iterator;

use strict;

use Rose::Object;
our @ISA = qw(Rose::Object);

our $VERSION = '0.01';

use Rose::Object::MakeMethods::Generic
(
  scalar => 
  [
    'error',
    'total',
    '_count',
    '_next_code',
    '_finish_code',
  ],

  'boolean' => 'active',
);

sub next
{
  my($self) = shift;
  my $ret = $self->_next_code->($self, @_);
  $self->active(0)  unless($ret);
  return $ret;
}

sub finish
{
  my($self) = shift;
  $self->active(0);
  return $self->_finish_code->($self, @_);
}

sub DESTROY
{
  my($self) = shift;
  $self->finish  if($self->active);
}

1;

__END__

=head1 NAME

Rose::DB::Objects::Iterator - Iterate over a series of Rose::DB::Objects.

=head1 SYNOPSIS

    $iterator = Rose::DB::Object::Manager->get_objects_iterator(...);

    while($object = $iterator->next)
    {
      # do stuff with $object...

      if(...) # bail out early
      {
        $iterator->finish;
        last;
      }
    }

    if($iterator->error)
    {
      print "There was an error: ", $iterator->error;
    }
    else
    {
      print "Total: ", $iterator->total;
    }

=head1 DESCRIPTION

C<Rose::DB::Objects::Iterator> is an iterator object that traverses a database query, returning C<Rose::DB::Object>-derived objects for each row.  C<Rose::DB::Objects::Iterator> objects are created by calls to the C<get_objects_iterator()> method of C<Rose::DB::Object::Manager> or one of its subclasses.

=head1 OBJECT METHODS

=over 4

=item B<error>

Returns the text message associated with the last error, or false if there was no error.

=item B<finish>

Prematurely stop the iteration (i.e., before iterating over all of the available objects).

=item B<next>

Return the next C<Rose::DB::Object>-derived object.  Returns false (but defined) if there are no more objects to iterate over, or undef if there was an error.

=item B<total>

Returns the total number of objects iterated over so far.

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
