package Rose::DB::Object::Metadata::Auto::Pg;

use strict;

use Carp();

use Rose::DB::Object::Metadata::UniqueKey;

use Rose::DB::Object::Metadata::Auto;
our @ISA = qw(Rose::DB::Object::Metadata::Auto);

our $VERSION = '0.725';

# Other useful columns, not selected for now
#   pg_get_indexdef(i.oid) AS indexdef
#   n.nspname AS schemaname, 
#   c.relname AS tablename,
#   i.relname AS indexname,
#   t.spcname AS "tablespace",
#   x.indisunique AS is_unique_index,
#
# Plus this join condition for table "t"
# LEFT JOIN pg_catalog.pg_tablespace t ON t.oid = i.reltablespace
use constant UNIQUE_INDEX_SQL => <<'EOF';
SELECT 
  x.indrelid,
  x.indkey,
  i.relname AS key_name
FROM 
  pg_catalog.pg_index x
  JOIN pg_catalog.pg_class c ON c.oid = x.indrelid
  JOIN pg_catalog.pg_class i ON i.oid = x.indexrelid
  LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE
  x.indisunique = 't' AND
  c.relkind     = 'r' AND 
  i.relkind     = 'i' AND
  n.nspname     = ?   AND
  c.relname     = ?
EOF

use constant UNIQUE_INDEX_COLUMNS_SQL_STUB => <<'EOF';
SELECT
  attname
FROM
  pg_catalog.pg_attribute
WHERE
  attrelid = ? AND
  attnum 
EOF

sub auto_generate_unique_keys
{
  my($self) = shift;

  unless(defined wantarray)
  {
    Carp::croak "Useless call to auto_generate_unique_keys() in void context";
  }

  my($class, @unique_keys);

  eval
  {
    $class = $self->class or die "Missing class!";

    my $db  = $self->db;
    my $dbh = $db->dbh or die $db->error;

    local $dbh->{'FetchHashKeyName'} = 'NAME';

    my $schema = $self->select_schema($db);
    $schema = $db->default_implicit_schema  unless(defined $schema);
    $schema = lc $schema  if(defined $schema);

    my $table = lc $self->table;

    my($relation_id, $column_nums, $key_name);

    my $sth = $dbh->prepare(UNIQUE_INDEX_SQL);

    $sth->execute($schema, $table);
    $sth->bind_columns(\($relation_id, $column_nums, $key_name));

    while($sth->fetch)
    {
      my $uk = Rose::DB::Object::Metadata::UniqueKey->new(name   => $key_name,
                                                          parent => $self);

      # Functional indexes show up this way, e.g. "... ON (LOWER(name))"
      next  if($column_nums eq '0'); 

      # column_nums is a space-separated list of numbers.  It's really an
      # "in2vector" data type, which seems sketchy to me, but whatever. 
      # We can fall back to the pg_get_indexdef() function and try to
      # parse that mess if this ever stops working.
      my @column_nums = grep { /^\d+$/ } split(/\s+/, $column_nums);

      my $col_sth = $dbh->prepare(UNIQUE_INDEX_COLUMNS_SQL_STUB . 
                                 ' IN(' . join(', ', @column_nums) . ')');

      my($column, @columns);

      $col_sth->execute($relation_id);
      $col_sth->bind_columns(\$column);

      while($col_sth->fetch)
      {
        push(@columns, $column);
      }

      unless(@columns)
      {
        die "No columns found for relation id $relation_id, column numbers @column_nums";
      }

      $uk->columns(\@columns);

      push(@unique_keys, $uk);
    }
  };

  if($@)
  {
    Carp::croak "Could not auto-retrieve unique keys for class $class - $@";
  }

  # This sort order is part of the API, and is essential to make the
  # test suite work.
  @unique_keys = sort { lc $a->name cmp lc $b->name } @unique_keys;

  return wantarray ? @unique_keys : \@unique_keys;
}

1;
