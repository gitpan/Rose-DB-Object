package Rose::DB::Object::Metadata;

use strict;

use Carp();

use Rose::Object;
our @ISA = qw(Rose::Object);

use Rose::DB::Object::Constants qw(PRIVATE_PREFIX);

use Rose::DB::Object::Metadata::ForeignKey;
use Rose::DB::Object::Metadata::Column::Scalar;

use Rose::Object::MakeMethods::Generic
(
  scalar => 
  [
    'class',
    'error',
    'primary_key_generator',
  ],

  boolean => 
  [
    allow_inline_column_values => { default => 0 },
  ],
);

use Rose::Class::MakeMethods::Generic
(
  inheritable_hash =>
  [
    column_type_classes => { interface => 'get_set_all' },
    column_type_class   => { interface => 'get_set', hash_key => 'column_type_classes' },
    delete_column_type_class => { interface => 'delete', hash_key => 'column_type_classes' },
  ],
);

__PACKAGE__->column_type_classes
(
  'scalar'    => 'Rose::DB::Object::Metadata::Column::Scalar',

  'char'      => 'Rose::DB::Object::Metadata::Column::Character',
  'character' => 'Rose::DB::Object::Metadata::Column::Character',
  'varchar'   => 'Rose::DB::Object::Metadata::Column::Varchar',
  'string'    => 'Rose::DB::Object::Metadata::Column::Varchar',

  'text'      => 'Rose::DB::Object::Metadata::Column::Text',
  'blob'      => 'Rose::DB::Object::Metadata::Column::Blob',

  'bits'      => 'Rose::DB::Object::Metadata::Column::Bitfield',
  'bitfield'  => 'Rose::DB::Object::Metadata::Column::Bitfield',

  'bool'      => 'Rose::DB::Object::Metadata::Column::Boolean',
  'boolean'   => 'Rose::DB::Object::Metadata::Column::Boolean',

  'int'       => 'Rose::DB::Object::Metadata::Column::Integer',
  'integer'   => 'Rose::DB::Object::Metadata::Column::Integer',

  'serial'    => 'Rose::DB::Object::Metadata::Column::Serial',

  'num'       => 'Rose::DB::Object::Metadata::Column::Numeric',
  'numeric'   => 'Rose::DB::Object::Metadata::Column::Numeric',
  'decimal'   => 'Rose::DB::Object::Metadata::Column::Numeric',
  'float'     => 'Rose::DB::Object::Metadata::Column::Float',

  'date'      => 'Rose::DB::Object::Metadata::Column::Date',
  'datetime'  => 'Rose::DB::Object::Metadata::Column::Datetime',
  'timestamp' => 'Rose::DB::Object::Metadata::Column::Timestamp',

  'datetime year to second' => 'Rose::DB::Object::Metadata::Column::DatetimeYearToSecond',
  'datetime year to minute' => 'Rose::DB::Object::Metadata::Column::DatetimeYearToMinute',

  'array'     => 'Rose::DB::Object::Metadata::Column::Array',
  'set'       => 'Rose::DB::Object::Metadata::Column::Set',

  'chkpass'   => 'Rose::DB::Object::Metadata::Column::Pg::Chkpass',
);

our %Class_Loaded;

our $VERSION = '0.012';

our $Debug = 0;

our %Objects;

sub new
{
  my($this_class, %args) = @_;
  my $class = $args{'class'} or Carp::croak "Missing required 'class' parameter";
  return $Objects{$class} ||= shift->SUPER::new(@_);
}

sub for_class
{
  return $Objects{$_[1]} ||= $_[0]->new(class => $_[1]);
}

sub prepare_select_options 
{
  @_ > 1 ? $_[0]->{'prepare_select_options'} = $_[1] : 
           $_[0]->{'prepare_select_options'} ||= {}
}

sub prepare_insert_options
{
  @_ > 1 ? $_[0]->{'prepare_insert_options'} = $_[1] : 
           $_[0]->{'prepare_insert_options'} ||= {}
}

sub prepare_update_options
{
  @_ > 1 ? $_[0]->{'prepare_update_options'} = $_[1] : 
           $_[0]->{'prepare_update_options'} ||= {}
}

sub prepare_delete_options
{
  @_ > 1 ? $_[0]->{'prepare_delete_options'} = $_[1] : 
           $_[0]->{'prepare_delete_options'} ||= {}
}

sub prepare_options
{
  my($self, $options) = @_;

  Carp::croak "Missing required hash ref argument to prepare_options()"
    unless(ref $options eq 'HASH');

  $self->prepare_select_options({ %$options });
  $self->prepare_insert_options({ %$options });
  $self->prepare_update_options({ %$options });
  $self->prepare_delete_options({ %$options });
}

sub table
{
  return $_[0]->{'table'}  unless(@_ > 1);
  $_[0]->_clear_table_generated_values;
  return $_[0]->{'table'} = $_[1];
}

sub schema
{
  return $_[0]->{'schema'}  unless(@_ > 1);
  $_[0]->_clear_table_generated_values;
  return $_[0]->{'schema'} = $_[1];
}

sub primary_key_columns
{
  my($self) = shift;

  if(@_)
  {
    $self->{'primary_key_columns'} = [];
    $self->add_primary_key_columns(@_);
  }

  return wantarray ? @{$self->{'primary_key_columns'} ||= []} : $self->{'primary_key_columns'};
}

sub add_primary_key_columns
{
  push(@{shift->{'primary_key_columns'}}, 
       ((@_ == 1 && ref $_[0] eq 'ARRAY') ? @{$_[0]} : @_));
}

*add_primary_key_column = \&add_primary_key_columns;

sub add_unique_key
{
  my($self) = shift;

  if(@_ == 1 && ref $_[0] eq 'ARRAY')
  {
    push(@{$self->{'unique_keys'}}, $_[0]);
  }
  else
  {
    push(@{$self->{'unique_keys'}}, [ @_ ]);
  }
}

sub unique_keys
{
  wantarray ? @{$_[0]->{'unique_keys'} ||= []} : $_[0]->{'unique_keys'};
}

sub column
{
  my($self, $name) = (shift, shift);

  if(@_)
  {
    my $spec = shift;

    #if(ref $spec eq 'HASH')
    #{
    #  return $self->{'columns'}{$name} =
    #    Rose::DB::Object::Metadata::Column->new(%$spec, name => $name);
    #}
    #els
    if(ref $spec && $spec->isa('Rose::DB::Object::Metadata::Column'))
    {
      $spec->name($name);
      return $self->{'columns'}{$name} = $spec;
    }
    else
    {
      Carp::croak "Invalid column specification: $_[0]";
    }
  }

  return $self->{'columns'}{$name}  if($self->{'columns'}{$name});
  return undef;
}

sub columns
{
  my($self) = shift;

  if(@_)
  {
    $self->{'columns'} = {};
    $self->{'primary_key_columns'} = [];
    $self->{'unique_keys'} = [];
    $self->add_columns(@_);
  }

  return wantarray ?
    (sort { $a->name cmp $b->name } values %{$self->{'columns'} ||= {}}) :
    [ sort { $a->name cmp $b->name } values %{$self->{'columns'} ||= {}} ];
}

sub add_columns
{
  my($self) = shift;

  my $class = ref $self;

  $self->_clear_column_generated_values;

  while(@_)
  {
    my $name = shift;

    if(ref $name && $name->isa('Rose::DB::Object::Metadata::Column'))
    {
      $self->{'columns'}{$name->name} = $name;
      next;
    }

    unless(ref $_[0])
    {
      my $column_class = $class->column_type_class('scalar')
        or Carp::croak "No column class set for column type 'scalar'";

      $Debug && warn $self->class, " - adding scalar column $name\n";
      $self->{'columns'}{$name} = $column_class->new(name => $name);
      next;
    }

    if(ref $_[0] eq 'HASH')
    {
      my $info = shift;

      if(my $pk = delete $info->{'primary_key'})
      {
        $Debug && warn $self->class, " - adding primary key column $name\n";
        $self->add_primary_key_column($name);
      }

      my $type = $info->{'type'} ||= 'scalar';

      my $column_class = $class->column_type_class($type)
        or Carp::croak "No column class set for column type '$type'";

      # Avoid string eval when possible...
      unless($Class_Loaded{$column_class})
      {
        eval "require $column_class";
        Carp::croak "Could not load '$column_class' for column type '$type"
          if($@);
        $Class_Loaded{$column_class}++;
      }


      $Debug && warn $self->class, " - adding $name $column_class\n";
      $self->{'columns'}{$name} = 
        $column_class->new(%$info, name => $name);
    }
    else
    {
      Carp::croak "Invalid column name or specification: $_[0]";
    }
  }
}

*add_column = \&add_columns;

sub add_foreign_keys
{
  my($self) = shift;

  while(@_)
  {
    my $name = shift;

    if(ref $name && $name->isa('Rose::DB::Object::Metadata::ForeignKey'))
    {
      $self->{'foreign_keys'}{$name->name} = $name;
      next;
    }

    if(ref $_[0] eq 'HASH')
    {
      my $info = shift;

      $Debug && warn $self->class, " - adding $name foreign key\n";
      $self->{'foreign_keys'}{$name} = 
        Rose::DB::Object::Metadata::ForeignKey->new(%$info, name => $name);
    }
    else
    {
      Carp::croak "Invalid foreign key specification: $_[0]";
    }
  }
}

*add_foreign_key = \&add_foreign_keys;

sub foreign_key
{
  my($self, $name) = (shift, shift);

  if(@_)
  {
    my $spec = shift;

    if(ref $spec eq 'HASH')
    {
      return $self->{'foreign_keys'}{$name} =
        Rose::DB::Object::Metadata::ForeignKey->new(%$spec, name => $name);
    }
    elsif(ref $spec && $spec->isa('Rose::DB::Object::Metadata::ForeignKey'))
    {
      $spec->name($name);
      return $self->{'foreign_keys'}{$name} = $spec;
    }
    else
    {
      Carp::croak "Invalid foreign key specification: $_[0]";
    }
  }

  return $self->{'foreign_keys'}{$name}  if($self->{'foreign_keys'}{$name});
  return undef;
}

sub foreign_keys
{
  my($self) = shift;

  if(@_)
  {
    $self->{'foreign_keys'} = {};
    $self->add_foreign_keys(@_);
  }

  return wantarray ?
    (sort { $a->name cmp $b->name } values %{$self->{'foreign_keys'} ||= {}}) :
    [ sort { $a->name cmp $b->name } values %{$self->{'foreign_keys'} ||= {}} ];
}

sub initialize
{
  my($self) = shift;
  my $class = ref $self;

  my $table = $self->table;
  Carp::croak "$class - Missing table name" 
    unless(defined $table && $table =~ /\S/);

  my @pk = $self->primary_key_columns;
  Carp::croak "$class - Missing primary key for table '$table'"  unless(@pk);

  my @column_names = $self->column_names;
  Carp::croak "$class - No columns defined for for table '$table'"
    unless(@column_names);

  $self->make_methods(@_);
}

sub make_methods
{
  my($self) = shift;
  my(%args) = @_;

  my $class =  $self->class;

  my %opts = 
  (
    target_class => $class, 
    ($args{'preserve_existing_methods'} ? (preserve_existing => 1) : ()),
    ($args{'override_existing_methods'} ? (override_existing => 1) : ()),
  );

  my $aliases = $self->column_aliases;
  my %methods;

  foreach my $column ($self->columns)
  {
    my $name = $column->name;

    my $method = $aliases->{$name} || $name;

    if(my $reason = $self->method_name_is_reserved($method, $class))
    {
      Carp::croak "Cannot create method '$method' - $reason  ",
                  "Use alias_column() to map it to another name."
    }

    $column->method_name($method);
    $methods{$name} = $method;

    # Let the method maker handle this I suppose...
    #next  if($class->can($method) && $args{'preserve_existing_methods'});

    $column->make_method(options => \%opts);
  }

  $self->column_methods(\%methods);

  foreach my $foreign_key ($self->foreign_keys)
  {
    my $method = $foreign_key->method_name || 
                 $foreign_key->method_name($foreign_key->name);

    if(my $reason = $self->method_name_is_reserved($method, $class))
    {
      Carp::croak "Cannot create method '$method' - $reason  ",
                  "Use alias_column() to map it to another name."
    }

    # Let the method maker handle this I suppose...
    #next  if($class->can($method) && $args{'preserve_existing_methods'});

    $foreign_key->make_method(options => \%opts);
  }
}

sub generate_primary_key_values
{
  my($self, $db) = @_;

  my $code = $self->primary_key_generator or 
    return $db->generate_primary_key_values(scalar @{$self->{'primary_key_columns'}});

  return $code->($self, $db);
}

sub generate_primary_key_placeholders
{
  my($self, $db) = @_;
  return $db->generate_primary_key_placeholders(scalar @{$self->{'primary_key_columns'}});
  #return((undef) x (scalar @{$self->{'primary_key_columns'}}));
}

sub column_names
{
  my($self) = shift;
  $self->{'column_names'} ||= [ sort { $a cmp $b } keys %{$self->{'columns'} ||= {}} ];
  return wantarray ? @{$self->{'column_names'}} : $self->{'column_names'};
}

sub column_names_sql
{
  my($self) = shift;
  return $self->{'column_names_sql'} ||= join(', ', $self->column_names);
}

sub method_column
{
  my($self, $method) = @_;

  unless(defined $self->{'method_columns'})
  {
    foreach my $column ($self->column_names)
    {
      my $method = $self->column_method($column);
      $self->{'method_column'}{$method} = $column;
    }
  }

  return $self->{'method_column'}{$method};
}

sub column_method_names
{
  my($self) = shift;
  $self->{'column_method_names'} ||= [ map { $self->column_method($_) } $self->column_names ];
  return wantarray ? @{$self->{'column_method_names'}} : $self->{'column_method_names'};
}

*column_accessor_method_names = \&column_method_names;
*column_mutator_method_names  = \&column_method_names;

sub alias_column
{
  my($self, $name, $new_name) = @_;

  Carp::croak "Usage: alias_column(column name, new name)"
    unless(@_ == 3);

  Carp::croak "No such column '$name' in table ", $self->table
    unless($self->{'columns'}{$name});

  Carp::croak "Pointless alias for '$name' to '$new_name' for table ", $self->table
    unless($name ne $new_name);

  foreach my $column ($self->primary_key_columns)
  {
    if($name eq $column)
    {
      Carp::croak "Cannot alias primary key column '$name'";
    }
  }

  $self->_clear_column_generated_values;

  $self->{'column_aliases'}{$name} = $new_name;
}

sub column_aliases
{
  return $_[0]->{'column_aliases'}  unless(@_ > 1);
  return $_[0]->{'column_aliases'} = (ref $_[1] eq 'HASH') ? $_[1] : { @_[1 .. $#_] };
}

sub column_method
{
  $_[0]->{'column_methods'}{$_[1]} ||= $_[0]->{'column_aliases'}{$_[1]} || $_[1];
}

*column_accessor_method = \&column_method;
*column_mutator_method  = \&column_method;

sub column_methods
{
  return $_[0]->{'column_methods'}  unless(@_ > 1);
  return $_[0]->{'column_methods'} = (ref $_[1] eq 'HASH') ? $_[1] : { @_[1 .. $#_] };
}

*column_accessor_methods = \&column_methods;
*column_mutator_methods  = \&column_methods;

sub fq_table_sql
{
  my($self) = shift;
  return $self->{'fq_table_sql'} ||= 
    join('.', grep { defined } ($self->schema, $self->table));
}

sub load_sql
{
  my($self, $key_columns) = @_;

 $key_columns ||= $self->primary_key_columns;

  no warnings;
  return $self->{'load_sql'}{join("\0", @$key_columns)} ||= 
    'SELECT ' . $self->column_names_sql . ' FROM ' .
    $self->fq_table_sql . ' WHERE ' .
    join(' AND ',  map { "$_ = ?" } @$key_columns);
}

sub load_sql_with_null_key
{
  my($self, $key_columns, $key_values) = @_;

  my $i = 0;

  no warnings;
  return 
    'SELECT ' . $self->column_names_sql . ' FROM ' .
    $self->fq_table_sql . ' WHERE ' .
    join(' AND ',  map { defined $key_values->[$i++] ? "$_ = ?" : "$_ IS NULL" }
    @$key_columns);
}

sub update_sql
{
  my($self, $key_columns) = @_;

  $key_columns ||= $self->primary_key_columns;

  my $cache_key = join("\0", @$key_columns);

  return $self->{'update_sql'}{$cache_key}
    if($self->{'update_sql'}{$cache_key});

  my %key = map { ($_ => 1) } @$key_columns;

  no warnings;
  return $self->{'update_sql'}{$cache_key} = 
    'UPDATE ' . $self->fq_table_sql . " SET \n" .
    join(",\n", map { "    $_ = ?" } grep { !$key{$_} } $self->column_names) .
    "\nWHERE " . join(' AND ', map { "$_ = ?" } @$key_columns);
}

# This is nonsensical right now because the primary key 
# always has to be non-null, and any update will use the 
# primary key instead of a unique key.  But I'll leave the
# code here (commented out) just in case.

# sub update_sql_with_null_key
# {
#   my($self, $key_columns, $key_values) = @_;
# 
#   my %key = map { ($_ => 1) } @$key_columns;
#   my $i = 0;
# 
#   no warnings;
#   return
#     'UPDATE ' . $self->fq_table_sql . " SET \n" .
#     join(",\n", map { "    $_ = ?" } grep { !$key{$_} } $self->column_names) .
#     "\nWHERE " . join(' AND ', map { defined $key_values->[$i++] ? "$_ = ?" : "$_ IS NULL" }
#     @$key_columns);
# }
#
# Ditto for this version of update_sql_with_inlining which handles null keys
# sub update_sql_with_inlining
# {
#   my($self, $obj, $key_columns, $key_values) = @_;
# 
#   my $db = $obj->db or Carp::croak "Missing db";
# 
#   $key_columns ||= $self->primary_key_columns;
#   
#   my %key = map { ($_ => 1) } @$key_columns;
# 
#   my @bind;
#   my @updates;
# 
#   foreach my $column (grep { !$key{$_} } $self->columns)
#   {
#     my $method = $self->column_method($column->name);
#     my $value  = $obj->$method();
#     
#     if($column->should_inline_value($db, $value))
#     {
#       push(@updates, "  $column = $value");
#     }
#     else
#     {
#       push(@updates, "  $column = ?");
#       push(@bind, $value);
#     }
#   }
# 
#   my $i = 0;
# 
#   no warnings;
#   return 
#   (
#     ($self->{'update_sql_with_inlining_start'} ||= 
#      'UPDATE ' . $self->fq_table_sql . " SET \n") .
#     join(",\n", @updates) . "\nWHERE " . 
#     join(' AND ', map { defined $key_values->[$i++] ? "$_ = ?" : "$_ IS NULL" }
#                   @$key_columns),
#     \@bind
#   );
# }

sub update_sql_with_inlining
{
  my($self, $obj, $key_columns) = @_;

  my $db = $obj->db or Carp::croak "Missing db";

  $key_columns ||= $self->primary_key_columns;

  my %key = map { ($_ => 1) } @$key_columns;

  my @bind;
  my @updates;

  foreach my $column (grep { !$key{$_} } $self->columns)
  {
    my $method = $self->column_method($column->name);
    my $value  = $obj->$method();

    if($column->should_inline_value($db, $value))
    {
      push(@updates, "  $column = $value");
    }
    else
    {
      push(@updates, "  $column = ?");
      push(@bind, $value);
    }
  }

  my $i = 0;

  no warnings;
  return 
  (
    ($self->{'update_sql_with_inlining_start'} ||= 
     'UPDATE ' . $self->fq_table_sql . " SET \n") .
    join(",\n", @updates) . "\nWHERE " . 
    join(' AND ', map { "$_ = ?" } @$key_columns),
    \@bind
  );
}

sub insert_sql
{
  my($self) = shift;

  no warnings;
  return $self->{'insert_sql'} ||= 
    'INSERT INTO ' . $self->fq_table_sql . "\n(\n" .
    join(",\n", map { "  $_" } $self->column_names) .
    "\n)\nVALUES\n(\n" . join(",\n", map { "  ?" } $self->column_names) .
    "\n)";
}

sub insert_sql_with_inlining
{
  my($self, $obj) = @_;

  unless(@_ > 1)
  {
    Carp::croak 'Missing required object argument to ',
                __PACKAGE__, '::insert_sql_with_inlining()'
  }

  my $db = $obj->db or Carp::croak "Missing db";

  my @bind;
  my @places;

  foreach my $column ($self->columns)
  {
    my $method = $self->column_method($column->name);
    my $value  = $obj->$method();

    if($column->should_inline_value($db, $value))
    {
      push(@places, "  $value");
    }
    else
    {
      push(@places, "  ?");
      push(@bind, $value);
    }
  }

  return 
  (
    ($self->{'insert_sql_with_inlining_start'} ||=
    'INSERT INTO ' . $self->fq_table_sql . "\n(\n" .
    join(",\n", map { "  $_" } $self->column_names) .
    "\n)\nVALUES\n(\n") . join(",\n", @places) . "\n)",
    \@bind
  );
}

sub delete_sql
{
  my($self) = shift;
  return $self->{'delete_sql'} ||= 
    'DELETE FROM ' . $self->fq_table_sql . ' WHERE ' .
    join(' AND ', map { "$_ = ?" } $self->primary_key_columns);
}

sub _clear_table_generated_values
{
  my($self) = shift;

  $self->{'fq_table_sql'} = undef;
  $self->{'load_sql'}     = undef;
  $self->{'update_sql'}   = undef;
  $self->{'insert_sql'}   = undef;
  $self->{'delete_sql'}   = undef;
}

sub _clear_column_generated_values
{
  my($self) = shift;

  $self->{'fq_table_sql'}        = undef;
  $self->{'column_names'}        = undef;
  $self->{'columns_names_sql'}   = undef;
  $self->{'column_method_names'} = undef;
  $self->{'method_columns'}      = undef;
  $self->{'load_sql'}   = undef;
  $self->{'update_sql'} = undef;
  $self->{'update_sql_with_inlining_start'} = undef;
  $self->{'insert_sql'} = undef;
  $self->{'insert_sql_with_inlining_start'} = undef;
  $self->{'delete_sql'} = undef;
}

sub method_name_is_reserved
{
  my($self, $name, $class) = @_;

  Carp::croak "Missing method name argument"  unless(defined $name);

  if(index($name, PRIVATE_PREFIX) == 0)
  {
    return "The method prefix '", PRIVATE_PREFIX, "' is reserved."
  }
  elsif($name =~ /^(?:meta|dbh?|_?init_db|error|not_found|load|save|update|insert|delete|DESTROY)$/ ||
        ($class->isa('Rose::DB::Object::Cached') && $name =~ /^(?:remember|forget(?:_all)?)$/))
  {
    return "This method name is reserved for use by the $class API."
  }

  return 0;
}

1;

__END__

=head1 NAME

Rose::DB::Object::Metadata - Database object metadata.

=head1 SYNOPSIS

  use Rose::DB::Object::Metadata;

  $meta = Rose::DB::Object::Metadata->new(class => 'Product');
  # ...or...
  # $meta = Rose::DB::Object::Metadata->for_class('Product');

  $meta->table('products');

  $meta->columns
  (
    id          => { type => 'int', primary_key => 1 },
    name        => { type => 'varchar', length => 255 },
    description => { type => 'text' },
    category_id => { type => 'int' },

    status => 
    {
      type      => 'varchar', 
      check_in  => [ 'active', 'inactive' ],
      default   => 'inactive',
    },

    start_date  => { type => 'datetime' },
    end_date    => { type => 'datetime' },

    date_created     => { type => 'timestamp', default => 'now' },  
    last_modified    => { type => 'timestamp', default => 'now' },
  );

  $meta->add_unique_key('name');

  $meta->foreign_keys
  (
    category =>
    {
      class       => 'Category',
      key_columns =>
      {
        category_id => 'id',
      }
    },
  );

  ...

=head1 DESCRIPTION

C<Rose::DB::Object::Metadata> objects store information about a single table in a database: the name of the table, the names and types of columns, any foreign keys, etc.  These metadata objects are also responsible for supplying information to, and creating object methods for the C<Rose::DB::Object>-derived objects to which they belong.

C<Rose::DB::Object::Metadata> objects objects are per-class singletons; there is one C<Rose::DB::Object::Metadata> object for each C<Rose::DB::Object>-derived class.

=head1 CLASS METHODS

=over 4

=item B<for_class CLASS>

Returns (or creates, if needed) the single C<Rose::DB::Object::Metadata> object associated with CLASS, where CLASS is the name of a C<Rose::DB::Object>-derived class.

=back

=head1 CONSTRUCTOR

=over 4

=item B<new PARAMS>

Returns (or creates, if needed) the single C<Rose::DB::Object::Metadata> associated with a particular C<Rose::DB::Object>-derived class, modifying or initializing it according to PARAMS, where PARAMS are name/value pairs.

Any object method is a valid parameter name, but PARAMS I<must> include a value for the C<class> parameter, since that's how C<Rose::DB::Object::Metadata> objects are mapped to their corresponding C<Rose::DB::Object>-derived class.

=back

=head1 OBJECT METHODS

=over 4

=item B<add_column ARGS>

This is an alias for the C<add_columns()> method.

=item B<add_columns ARGS>

Add the columns specified by ARGS to the list of columns for the table.  Columns can be specified in ARGS in several ways.

If an argument is a subclass of C<Rose::DB::Object::Metadata::Column>, it is added as-is.

If an argument is a plain scalar, it is taken as the name of a scalar column.  A column object of the class returned by the method call C<column_type_class('scalar')> is constructed and then added.

Otherwise, only name/value pairs are considered, where the name is taken as the column name and the value must be a reference to a hash.

If the hash contains the key "primary_key", it is deleted.  If the value of the "primary_key" key is true, then the column name is added as a primary key by calling the C<add_primary_key_column()> method with the column name as its argument.

Then the C<column_type_class()> method is called with the value of the "type" hash key as its argument (or "scalar" if that key is missing), returning the name of a column class.  Finally, a new column object of that class is constructed and is passed all the remaining pairs in the hash reference, along with the name and type of the column.  That column object is then added to the list of columns.

This is done until there are no more arguments to be processed, or until an argument does not conform to one of the required formats, in which case a fatal error occurs.

Example:

    $meta->add_columns
    (
      # Add a scalar column
      'name', 
      #
      # which is roughly equivalent to:
      #
      # $class = $meta->column_type_class('scalar');
      # $col = $class->new(name => 'name');
      # (then add $col to the list of columns)

      # Add by name/hashref pair
      age => { type => 'int', default => 5 },
      #
      # which is roughly equivalent to:
      #
      # $class = $meta->column_type_class('int');
      # $col = $class->new(name    => 'age',
      #                    type    => 'int', 
      #                    default => 5, );
      # (then add $col to the list of columns)

      # Add a column object directly
      Rose::DB::Object::Metadata::Column::Date->new(
        name => 'start_date'),
    );

=item B<add_foreign_keys ARGS>

Add foreign keys as specified by ARGS.  Foreign keys can be specified in ARGS in several ways.

If an argument is a subclass of C<Rose::DB::Object::Metadata::ForeignKey>, it is added as-is.

Otherwise, only name/value pairs are considered, where the name is taken as the foreign key name and the value must be a reference to a hash.

A new C<Rose::DB::Object::Metadata::ForeignKey> object is constructed and is passed all the pairs in the hash reference, along with the name of the foreign key as the value of the "name" parameter.  That foreign key object is then added to the list of foreign keys.

This is done until there are no more arguments to be processed, or until an argument does not conform to one of the required formats, in which case a fatal error occurs.

Example:

    $meta->add_foreign_keys
    (      
      # Add by name/hashref pair
      category => 
      {
        class       => 'Category', 
        key_columns => { category_id => 'id' },
      },
      #
      # which is roughly equivalent to:
      #
      # $fk = Rose::DB::Object::Metadata::ForeignKey->new(
      #         class       => 'Category', 
      #         key_columns => { category_id => 'id' },
      #         name        => 'category');
      # (then add $fk to the list of foreign keys)

      # Add a foreign key object directly
      Rose::DB::Object::Metadata::ForeignKey->new(...),
    );

=item B<add_primary_key_column COLUMN>

This method is an alias for C<add_primary_key_columns()>.

=item B<add_primary_key_columns COLUMNS>

Add COLUMNS to the list of columns that make up the primary key.  COLUMNS can be a list or reference to an array of column names.

=item B<add_unique_key COLUMNS>

Add a new unique key made up of COLUMNS, where COLUMNS is a list or a reference to an array of the column names that make up the key.

=item B<alias_column NAME, ALIAS>

Use ALIAS instead of NAME as the accessor method name for column named NAME.  Note that primary key columns cannot be aliased.  If the column NAME is part of the primary key, a fatal error will occur.

It is sometimes necessary to use an alias for a column because the column name  conflicts with an existing C<Rose::DB::Object> method name.

For example, imagine a column named "save".  The C<Rose::DB::Object> API already defines a method named C<save()>, so obviously that name can't be used for the accessor method for the "save" column.  To solve this, make an alias:

    $meta->alias_column(save => 'save_flag');

See the C<Rose::DB::Object> documentation or call the C<method_name_is_reserved()> method to determine if a method name is reserved.

=item B<allow_inline_column_values [BOOL]>

Get or set the boolean flag that indicates whether or not the associated C<Rose::DB::Object>-derived class should try to inline column values that C<DBI> does not handle correctly when they are bound to placeholders using C<bind_columns()>.  The default value is false.

Enabling this flag reduces the performance of the C<update()> and C<insert()> operations on the C<Rose::DB::Object>-derived object.  But it is sometimes necessary to enable the flag because some C<DBI> drivers do not (or cannot) always do the right thing when binding values to placeholders in SQL statements.  For example, consider the following SQL for the Informix database:

    CREATE TABLE test (d DATETIME YEAR TO SECOND);
    INSERT INTO test (d) VALUES (CURRENT);

This is valid Informix SQL and will insert a row with the current date and time into the "test" table. 

Now consider the following attempt to do the same thing using C<DBI> placeholders (assume the table was already created as per the CREATE TABLE statement above):

    $sth = $dbh->prepare('INSERT INTO test (d) VALUES (?)');
    $sth->execute('CURRENT'); # Error!

What you'll end up with is an error like this:

    DBD::Informix::st execute failed: SQL: -1262: Non-numeric 
    character in datetime or interval.

In other words, DBD::Informix has tried to quote the string "CURRENT", which has special meaning to Informix only when it is not quoted. 

In order to make this work, the value "CURRENT" must be "inlined" rather than bound to a placeholder when it is the value of a "DATETIME YEAR TO SECOND" column in an Informix database.

=item B<class [CLASS]>

Get or set the C<Rose::DB::object>-derived class associated with this metadata object.  This is the class where the accessor methods for each column will be created (by C<make_methods()>).

=item B<column NAME [, COLUMN]>

Get or set the column named NAME.  If just NAME is passed, the C<Rose::DB::Object::Metadata::Column>-derived column object for the column of that name is returned.  If no such column exists, undef is returned.

If both NAME and COLUMN are passed, then COLUMN must be a C<Rose::DB::Object::Metadata::Column>-derived object.  COLUMN has its C<name()> set to NAME, and is then stored as the column metadata object for NAME.

=item B<columns [ARGS]>

Get or set the full list of columns.  If ARGS are passed, the column list is cleared and then ARGS are passed to the C<add_columns()> method.

Returns a list of column objects in list context, or a reference to an array of column objects in scalar context.

=item B<column_accessor_method COLUMN>

Returns the name of the "get" method for COLUMN.  This is currently just an alias for C<column_method()> but should still be used for the sake of clarity when you're only interested in a method you can use to get the column value.

=item B<column_aliases [MAP]>

Get or set the hash that maps column names to their aliases.  If passed MAP (a list of name/value pairs or a reference to a hash) then MAP replaces the current alias mapping.  Returns a reference to the hash that maps column names to their aliases.

Note that modifying this map has no effect if C<initialize()> or C<make_methods()> has already been called for the current C<class>.

=item B<column_method COLUMN>

Returns the name of the get/set accessor method for COLUMN.  If the column is not aliased, then the accessor name is the same as the column name.

=item B<column_methods [MAP]>

Get or set the hash that maps column names to their get/set accessor method names.  If passed MAP (a list of name/value pairs or a reference to a hash) then MAP replaces the current method mapping.

Note that modifying this map has no effect if C<initialize()> or C<make_methods()> has already been called for the current C<class>.

=item B<column_method_names>

Returns a list (in list context) or a reference to an array (in scalar context) of method names for all columns, ordered according to the order that the column names are returned from the C<column_names()> method.

=item B<column_mutator_method COLUMN>

Returns the name of the "set" method for COLUMN.  This is currently just an alias for C<column_method()> but should still be used for the sake of clarity when you're only interested in a method you can use to set the column value.

=item B<column_names>

Returns a list (in list context) or a reference to an array (in scalar context) of column names.

=item B<column_type_class TYPE>

Given the column type string TYPE, return the name of the C<Rose::DB::Object::Metadata::Column>-derived class used to store metadata and create the accessor method(s) for columns of that type.

=item B<column_type_classes [MAP]>

Get or set the hash that maps column type strings to the names of the C<Rose::DB::Object::Metadata::Column>-derived classes used to store metadata  and create accessor method(s) for columns of that type.

If passed MAP (a list of type/class pairs or a reference to a hash of the same) then MAP replaces the current column type mapping.  Returns a list of type/class pairs (in list context) or a reference to the hash of type/class mappings (in scalar context).

The default mapping of type names to class names is:

  scalar    => Rose::DB::Object::Metadata::Column::Scalar

  char      => Rose::DB::Object::Metadata::Column::Character
  character => Rose::DB::Object::Metadata::Column::Character
  varchar   => Rose::DB::Object::Metadata::Column::Varchar
  string    => Rose::DB::Object::Metadata::Column::Varchar

  text      => Rose::DB::Object::Metadata::Column::Text
  blob      => Rose::DB::Object::Metadata::Column::Blob

  bits      => Rose::DB::Object::Metadata::Column::Bitfield
  bitfield  => Rose::DB::Object::Metadata::Column::Bitfield

  bool      => Rose::DB::Object::Metadata::Column::Boolean
  boolean   => Rose::DB::Object::Metadata::Column::Boolean

  int       => Rose::DB::Object::Metadata::Column::Integer
  integer   => Rose::DB::Object::Metadata::Column::Integer

  serial    => Rose::DB::Object::Metadata::Column::Serial

  num       => Rose::DB::Object::Metadata::Column::Numeric
  numeric   => Rose::DB::Object::Metadata::Column::Numeric
  decimal   => Rose::DB::Object::Metadata::Column::Numeric
  float     => Rose::DB::Object::Metadata::Column::Float

  date      => Rose::DB::Object::Metadata::Column::Date
  datetime  => Rose::DB::Object::Metadata::Column::Datetime
  timestamp => Rose::DB::Object::Metadata::Column::Timestamp

  'datetime year to second' =>
    Rose::DB::Object::Metadata::Column::DatetimeYearToSecond

  'datetime year to minute' =>
    Rose::DB::Object::Metadata::Column::DatetimeYearToMinute

  array     => Rose::DB::Object::Metadata::Column::Array
  set       => Rose::DB::Object::Metadata::Column::Set

  chkpass   => Rose::DB::Object::Metadata::Column::Pg::Chkpass

=item B<delete_column_type_class TYPE>

Delete the type/class mapping entry for the column type TYPE.

=item B<foreign_key NAME [, VALUE]>

Get or set the foreign key named NAME.  NAME should be the name of the thing being referenced by the foreign key, I<not> the name of any of the columns that make up the foreign key.  If called with just a NAME argument, the foreign key stored under that name is returned.  Undef is returned if there is no such foreign key.

If passed a VALUE that is a reference to a hash, a new C<Rose::DB::Object::Metadata::ForeignKey> object is constructed, with the name/value pairs in the hash passed to the constructor, along with the NAME as the value of the C<name> parameter.

If VALUE is a C<Rose::DB::Object::Metadata::ForeignKey>->derived object, it has its C<name> set to NAME and then is stored under that name.

=item B<fq_table_sql>

Returns the fully-qualified table name in a form suitable for use in an SQL statement.

=item B<generate_primary_key_values DB>

Given the C<Rose::DB>-derived object DB, generate new values for the primary key column(s) of the table described by this metadata object.  If a C<primary_key_generator> is defined, it will be called (passed this metadata object and the DB) and its value(s) returned.  If not, a list of undef values is returned (one for each primary key column).

=item B<initialize [ARGS]>

Initialize the C<Rose::DB::object>-derived class associated with this metadata object by creating accessor methods for each column and foreign key.  The C<table> name and the C<primary_key> must be defined or a fatal error will occur.

ARGS, if any, are passed to the call to C<make_methods()> that actually creates the methods.

=item B<make_methods [ARGS]>

Create accessor methods in C<class> for each column and foreign key.  ARGS are name/value pairs, and are all optional.  Valid parameters are:

=over 4

=item * C<preserve_existing_methods>

If set to a true value, a method will not be created if there is already an existing method with the same named.

=item * C<override_existing_methods>

If set to a true value, override any existing methods with the same name.

=back

In the absence of one of these parameters, any method name that conflicts with an existing method name will cause a fatal error.

For each column, the corresponding accessor method name is determined by passing the column name to C<column_method()>.  If the method name is reserved (according to C<method_name_is_reserved()>, a fatal error will occur.  The accessor method is created by calling the column object's C<make_method()> method.

For each foreign key, the corresponding accessor method name is determined by calling the C<method_name()> method on the foreign key metadata object.  If the method name is reserved (according to C<method_name_is_reserved()>), a fatal error will occur.  The accessor method is created by calling the foreign key metadata object's C<make_method()> method.

=item B<method_column METHOD>

Returns the name of the column manipulated by the get/set accessor method named METHOD.  If the column is not aliased, then the accessor name is the same as the column name.

=item B<method_name_is_reserved NAME, CLASS>

Given the method name NAME and the class name CLASS, returns true if the method name is reserved (i.e., is used by the CLASS API), false otherwise.

=item B<primary_key_columns [COLUMNS]>

Get or set the list of of columns that make up the primary key.  If COLUMNS are passed, the list is emptied and then COLUMNS are passed to the C<add_primary_key_columns()> method.  Returns a list of primary key column names (in list context) or a reference to the array of primary key column names (in scalar context).

=item B<primary_key_generator [CODE]>

Get or set the subroutine used to generate new primary key values for the primary key columns of this table.  The subroutine will be passed two arguments: the current metadata object and the C<Rose::DB>-derived object that points to the current database.

The subroutine is expected to return a list of values, one for each primary key column.  The values must be in the same order as the corresponding columns returned by C<primary_key_columns()>. (i.e., the first value belongs to the first column returned by C<primary_key_columns()>, the second value belongs to the second column, and so on.)

=item B<schema [SCHEMA]>

Get or set the database schema name.  This attribute is only applicable to PostgreSQL databases.

=item B<table [TABLE]>

Get or set the database table name.

=item B<unique_keys>

Returns the list (in list context) or reference to the array (in scalar context) of groups of column names for each unique key.  Each group of column names is stored as a reference to an array of column names.

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
