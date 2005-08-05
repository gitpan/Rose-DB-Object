package Rose::DB::Object::Metadata::Auto::MySQL;

use strict;

use Carp();

use Rose::DB::Object::Metadata::UniqueKey;

use Rose::DB::Object::Metadata::Auto;
our @ISA = qw(Rose::DB::Object::Metadata::Auto);

our $VERSION = '0.01';

sub auto_retrieve_primary_key_column_names
{
  my($self) = shift;

  unless(defined wantarray)
  {
    Carp::croak "Useless call to auto_retrieve_primary_key_column_names() in void context";
  }
  
  my($class, @columns);

  eval
  {
    $class = $self->class or die "Missing class!";
  
    my $db  = $self->db;
    my $dbh = $db->dbh or die $db->error;

    my $sth = $dbh->prepare('SHOW INDEX FROM ' . $self->fq_table_sql);
    $sth->execute;

    while(my $row = $sth->fetchrow_hashref)
    {
      next  unless($row->{'Key_name'} eq 'PRIMARY');
      push(@columns, $row->{'Column_name'});
    }
  };

  if($@ || !@columns)
  {
    $@ = 'no primary key coumns found'  unless(defined $@);
    Carp::croak "Could not auto-retrieve primary key columns for class $class - $@";
  }

  return wantarray ? @columns : \@columns;
}

sub auto_generate_unique_keys
{
  my($self) = shift;

  unless(defined wantarray)
  {
    Carp::croak "Useless call to auto_generate_unique_keys() in void context";
  }

  my($class, %unique_keys);

  eval
  {
    $class = $self->class or die "Missing class!";
  
    my $db  = $self->db;
    my $dbh = $db->dbh or die $db->error;

    my $sth = $dbh->prepare('SHOW INDEX FROM ' . $self->fq_table_sql);
    $sth->execute;

    while(my $row = $sth->fetchrow_hashref)
    {
      next  if($row->{'Non_unique'} || $row->{'Key_name'} eq 'PRIMARY');

      my $uk = $unique_keys{$row->{'Key_name'}} ||= 
        Rose::DB::Object::Metadata::UniqueKey->new(name   => $row->{'Key_name'}, 
                                                   parent => $self);

      $uk->add_column($row->{'Column_name'});
    }
  };

  if($@)
  {
    Carp::croak "Could not auto-retrieve unique keys for class $class - $@";
  }

  return wantarray ? values %unique_keys : [ values %unique_keys ];
}

1;
