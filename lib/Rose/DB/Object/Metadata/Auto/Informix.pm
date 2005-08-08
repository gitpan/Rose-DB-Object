package Rose::DB::Object::Metadata::Auto::Informix;

use strict;

use Carp();

use Rose::DB::Object::Metadata::UniqueKey;

use Rose::DB::Object::Metadata::Auto;
our @ISA = qw(Rose::DB::Object::Metadata::Auto);

our $VERSION = '0.01';

# syscolumns.coltype constants taken from:
#
# http://www-306.ibm.com/software/data/informix/pubs/library/datablade/dbdk/sqlr/01.fm14.html

use constant CHAR       =>  0;
use constant SMALLINT   =>  1;
use constant INTEGER    =>  2;
use constant FLOAT      =>  3;
use constant SMALLFLOAT =>  4;
use constant DECIMAL    =>  5;
use constant SERIAL     =>  6;
use constant DATE       =>  7;
use constant MONEY      =>  8;
use constant NULL       =>  9;
use constant DATETIME   => 10;
use constant BYTE       => 11;
use constant TEXT       => 12;
use constant VARCHAR    => 13;
use constant INTERVAL   => 14;
use constant NCHAR      => 15;
use constant NVARCHAR   => 16;
use constant INT8       => 17;
use constant SERIAL8    => 18;
use constant SET        => 19;
use constant MULTISET   => 20;
use constant LIST       => 21;
use constant ROW        => 22;
use constant COLLECTION => 23;
use constant ROWREF     => 24;

use constant VARIABLE_LENGTH_OPAQUE =>   40; # Variable-length opaque type
use constant FIXED_LENGTH_OPAQUE    =>   41; # Fixed-length opaque type
use constant NAMED_ROW_TYPE         => 4118; # Named row type 

# Map the Informix column type constants to type names that we can
# handle--or that are at least in our format: lowercase text.
my %Column_Types =
(
  CHAR()       => 'char',
  SMALLINT()   => 'int',
  INTEGER()    => 'int',
  FLOAT()      => 'float',
  SMALLFLOAT() => 'float',
  DECIMAL()    => 'decimal',
  SERIAL()     => 'serial',
  DATE()       => 'date',
  MONEY()      => 'decimal',
  NULL()       => 'null',
  DATETIME()   => 'datetime',
  BYTE()       => 'byte',
  TEXT()       => 'text',
  VARCHAR()    => 'varchar',
  INTERVAL()   => 'interval',
  NCHAR()      => 'char',
  NVARCHAR()   => 'varchar',
  INT8()       => 'int',
  SERIAL8()    => 'serial',
  SET()        => 'set',
  MULTISET()   => 'multiset',
  LIST()       => 'list',
  ROW()        => 'row',
  COLLECTION() => 'collection',
  ROWREF()     => 'rowref',
);

# http://www-306.ibm.com/software/data/informix/pubs/library/datablade/dbdk/sqlr/01.fm14.html
my %Column_Length =
(
  # Data Type   Length (in bytes)
  SMALLINT() => 2,
  INTEGER()  => 4,
  INT8()     => 8,
);

# http://www-306.ibm.com/software/data/informix/pubs/library/datablade/dbdk/sqlr/01.fm14.html
my %Datetime_Qualifiers =
(
   0 => 'year',
   2 => 'month',
   4 => 'day',
   6 => 'hour',
   8 => 'minute',
  10 => 'second',
  11 => 'fraction(1)',
  12 => 'fraction(2)',
  13 => 'fraction(3)',
  14 => 'fraction(4)',
  15 => 'fraction(5)',
);

# $INFORMIXDIR/etc/xpg4_is.sql
# http://www-306.ibm.com/software/data/informix/pubs/library/datablade/dbdk/sqlr/01.fm50.html
my %Numeric_Precision =
(
  SMALLINT()   =>  5,
  INTEGER()    => 10,
  FLOAT()      => 63,
  SMALLFLOAT() => 32,
);

# These constants are from the DBI documentation.  Is there somewhere 
# I can load these from?
use constant SQL_NO_NULLS => 0;
use constant SQL_NULLABLE => 1;

sub auto_generate_columns
{
  my($self) = shift;

  my($class, %columns, $table_id);

  eval
  {
    require DBD::Informix::Metadata;

    $class = $self->class or die "Missing class!";

    my $db  = $self->db;  
    my $dbh = $db->dbh or die $db->error;

    # Informix does not support DBI's column_info() method so we have
    # to get all that into "the hard way."
    #
    # Each item in @col_list is a reference to an array of values:
    #
    #   0     owner name
    #   1     table name
    #   2     column number
    #   3     column name
    #   4     data type (encoded)
    #   5     data length (encoded)
    #
    my @col_list = DBD::Informix::Metadata::ix_columns($dbh, $self->table);

    # We'll also need to query the syscolumns table directly to get the
    # table id, which we need to query the sysdefaults table.  But to get
    # the correct syscolumns record, we need to first query the systables
    # table.
    my $st_sth = $dbh->prepare(<<"EOF");
SELECT tabid FROM informix.systables WHERE tabname = ? AND owner = ?
EOF

    my %col_info;

    foreach my $item (@col_list)
    {
      # We're going to build a standard DBI column_info() data structure
      # to pass on to the rest of the code.
      my $col_info;

      # Add the "proprietary" values using the DBI convention of lowercase
      # names prefixed with DBD name.
      my @keys = map { "informix_$_" } 
        qw(owner table column_number column_name column_type column_length);

      @$col_info{@keys} = @$item;

      # Copy the "easy" values into the standard DBI locations
      $col_info->{'TABLE_NAME'}  = $col_info->{'informix_table'};
      $col_info->{'COLUMN_NAME'} = $col_info->{'informix_column_name'};

      # Query the systables table to get the table id based on the 
      # table name and owner name.
      $st_sth->execute(@$col_info{qw(informix_table informix_owner)});

      $table_id = $st_sth->fetchrow_array;
      
      unless(defined $table_id)
      {
        die "Could not find informix.systables record for table '",
             $col_info->{'informix_table'}, "' with owner '",
             $col_info->{'informix_owner'}, "'";
      }

      $col_info->{'informix_tabid'} = $table_id;

      # Store the column info by column name
      $col_info{$col_info->{'COLUMN_NAME'}} = $col_info;
    }

    # We need to query the syscolumns table directly to get the
    # table id, which we need to query the sysdefaults table. 
    my $sc_sth = $dbh->prepare(<<"EOF");
SELECT * FROM informix.syscolumns WHERE tabid = ?
EOF

    # We may need to query the sysxtdtypes table, so reserve a
    # variable for that statement handle.  We'll also cache the
    # results, so we'll set up that hash here too.  We'll also
    # need a mapping from "colno" to column name.
    my($sxt_sth, %extended_type, %colno_to_name);

    # Query the syscolumns table to get somemore column information
    $sc_sth->execute($table_id);
    
    while(my $sc_row = $sc_sth->fetchrow_hashref)
    {
      my $col_info = $col_info{$sc_row->{'colname'}}
        or die "No column info found for column name '$sc_sth->{'colname'}'";

      # Copy all the row values into the DBI column info using the DBI 
      # convention of lowercase names prefixed with DBD name.
      @$col_info{map { "informix_$_" } keys %$sc_row} = values %$sc_row;

      # Store mapping from "colno" to column name
      $colno_to_name{$sc_row->{'colno'}} = $sc_row->{'colname'};

      ##
      ## Painfully derive the data type name (TYPE_NAME)
      ##

      # If the coltype is a value greater than 256, the the column does
      # not allow null values.  To determine the data type for a coltype
      # column that contains a value greater than 256, subtract 256 from the
      # value and evaluate the remainder, based on the possible coltype
      # values.  For example, if a column has a coltype value of 262,
      # subtracting 256 from 262 leaves a remainder of 6, which indicates
      # that this column uses a SERIAL data type.

      my $type_num;

      if($sc_row->{'coltype'} > 256)
      {
        $col_info->{'informix_type_num'} = $type_num = 
          $sc_row->{'coltype'} - 256;

        # This situation also indicates that the column is NOT NULL,
        # so set all the DBI-style attributes to indicate that.
        $col_info->{'IS_NULLABLE'} = 'NO';
        $col_info->{'NULLABLE'}    = SQL_NO_NULLS;
      }
      else
      {
        $col_info->{'informix_type_num'} = $type_num = $sc_row->{'coltype'};

        $col_info->{'IS_NULLABLE'} = 'YES';
        $col_info->{'NULLABLE'}    = SQL_NULLABLE;      
      }
      
      #
      # Now we need to turn $type_num into a type name.  Hold on to your hat.
      #

      my $type_name;

      # The following data types are implemented by the database server
      # as built-in opaque types: BLOB, BOOLEAN, CLOB, and LVARCHAR
      #
      # A built-in opaque data type is one for which the database server
      # provides the type definition.  Because these data types are built-in
      # opaque types, they do not have a unique coltype value.  Instead, they
      # have one of the coltype values for opaque types: 41 (fixed-length
      # opaque type), or 40 (varying-length opaque type). The different
      # fixed-length opaque types are distinguished by the extended_id column
      # in the sysxtdtypes system catalog table.
      #
      # The following table summarizes the coltype values for the predefined
      # data types.
      #
      # Type       coltype   symbolic constant
      # --------   -------   -----------------
      # BLOB          41     FIXED_LENGTH_OPAQUE
      # CLOB          41     FIXED_LENGTH_OPAQUE
      # BOOLEAN       41     FIXED_LENGTH_OPAQUE
      # LVARCHAR      40     VARIABLE_LENGTH_OPAQUE

       # BLOB, CLOB, or BOOLEAN
      if($type_num == FIXED_LENGTH_OPAQUE)
      {
        # Maybe we already looked this one up
        if($extended_type{$sc_row->{'extended_id'}})
        {
          $type_name = $extended_type{$col_info->{'informix_extended_id'}};
        }
        else # look it up and cache it
        {
          $sxt_sth ||= 
            $dbh->prepare("SELECT name FROM informix.sysxtdtypes WHERE extended_id = ?");

          $sxt_sth->execute($sc_row->{'extended_id'});

          my $name = $sxt_sth->fetchrow_array;

          # We only handle BOOLEANS specially, and the name column for
          # booleans is already in our type name format: "boolean"
          # So just copy the name value into the cache.
          $type_name = $extended_type{$sc_row->{'extended_id'}} = $name;
        }
      }
      elsif($type_num == VARIABLE_LENGTH_OPAQUE) # LVARCHAR
      {
        $type_name = 'varchar';
      }
      elsif($type_num == DATETIME)
      {
        # Determine the full "datetime X to Y" type string
        $type_name = _ix_datetime_specific_type($type_num, $sc_row->{'collength'});
      }
      else
      {
        $type_name = $Column_Types{$type_num};
      }

      # Finally, set the type name
      $col_info->{'TYPE_NAME'} = $type_name;

      #
      # Mine column length for information
      #
      
      # COLUMN_SIZE is the maximum length in characters for character data
      # types, the number of digits or bits for numeric data types or the
      # length in the representation of temporal types. See the relevant
      # specifications for detailed information.

      $col_info->{'COLUMN_SIZE'} = 
        _ix_max_length($type_num, $sc_row->{'collength'});

      if($type_num == SMALLINT || $type_num == INTEGER ||
         $type_num == SERIAL   || $type_num == DECIMAL ||
         $type_num == MONEY)
      {
        $col_info->{'DECIMAL_DIGITS'} = 
          _ix_numeric_scale($type_num, $sc_row->{'collength'});

        $col_info->{'COLUMN_SIZE'} =
          _ix_numeric_precision($type_num, $sc_row->{'collength'});
          
        $col_info->{'NUM_PREC_RADIX'} =
          _ix_numeric_precision_radix($type_num, $sc_row->{'collength'});
      }
    }

    #
    # Get all the column default values from the sysdefaults table
    #

    # class 'T' means "table" (the other possible value us "t" for "row type")
    # http://www-306.ibm.com/software/data/informix/pubs/library/datablade/dbdk/sqlr/01.fm16.html
    my $sd_sth = $dbh->prepare(<<"EOF");
SELECT * FROM informix.sysdefaults WHERE tabid = ? AND class = 'T'
EOF

    $sd_sth->execute($table_id);
    
    while(my $sd_row = $sd_sth->fetchrow_hashref)
    {
      my $col_name = $colno_to_name{$sd_row->{'colno'}}
        or die "While getting defaults: no column name found for colno '$sd_row->{'colno'}'";

      my $col_info = $col_info{$col_name}
        or die "While getting defaults: no column info found for column '$col_name'";

      # The "type" column of the sysdefaults table looks like this:
      #
      # type  CHAR(1)
      #
      # 'L' = Literal default
      # 'U' = User
      # 'C' = Current
      # 'N' = Null
      # 'T' = Today
      # 'S' = Dbservername 
      #
      # If a literal is specified for the default value, it is stored in
      # the default column as text. If the literal value is not of type
      # CHAR, the default column consists of two parts. The first part is
      # the 6-bit representation of the binary value of the default-value
      # structure. The second part is the default value in English text.
      # The two parts are separated by a space.
      #
      # If the data type of the column is not CHAR or VARCHAR, a binary
      # representation is encoded in the default column. 

      if($sd_row->{'type'} eq 'T')
      {
        $col_info->{'COLUMN_DEF'} = 'today';
      }
      elsif($sd_row->{'type'} eq 'C')
      {
        $col_info->{'COLUMN_DEF'} = 'current';
      }
      elsif($sd_row->{'type'} eq 'L')
      {
        if($col_info->{'informix_type_num'} == CHAR)
        {
          $col_info->{'COLUMN_DEF'} = $sd_row->{'default'};
        }
        else
        {
          # The first part is the 6-bit representation of the binary value
          # of the default-value structure. The second part is the default
          # value in English text. The two parts are separated by a space.
          my $default = $sd_row->{'default'};
          $default =~ s/^.+ //; # cheat by just looking for the space
          
          $col_info->{'COLUMN_DEF'} = $default;
        }
      }
    }

    # Finally, generate the columns based on the DBI-like $col_info
    # that we built in the previous steps.
    
    foreach my $col_info (values %col_info)
    {
      $columns{$col_info->{'COLUMN_NAME'}} = 
        $self->auto_generate_column($col_info->{'COLUMN_NAME'}, $col_info);
    }
  };

  if($@ || !keys %columns)
  {
    Carp::croak "Could not auto-generate columns for class $class - $@";
  }

  return wantarray ? values %columns : \%columns;
}

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
    require DBD::Informix::Metadata;

    $class = $self->class or die "Missing class!";

    my $db  = $self->db;  
    my $dbh = $db->dbh or die $db->error;

    # We need the table owner.  Asking for column information is the only
    # way I know of to reliably get this information.
    #
    # Informix does not support DBI's column_info() method so we have
    # to get all that into "the hard way."
    #
    # Each item in @col_list is a reference to an array of values:
    #
    #   0     owner name
    #   1     table name
    #   2     column number
    #   3     column name
    #   4     data type (encoded)
    #   5     data length (encoded)
    #
    my @col_list = DBD::Informix::Metadata::ix_columns($dbh, $self->table);

    my $owner = $col_list[0][0];
    my $table = $col_list[0][1]; # just in case...

    unless(defined $owner)
    {
      die "Could not find owner for table ", $self->table;
    }

    # Then comes this monster query to get the primary key column names.
    # I'd love to know a better/easier way to do this...
    my $pk_sth = $dbh->prepare(<<'EOF');
SELECT 
  col.colname
FROM
  informix.sysconstraints con, 
  informix.systables      tab,
  informix.sysindexes     idx,
  informix.syscolumns     col
WHERE
   constrtype  = 'P'       AND 
   con.tabid   = tab.tabid AND
   con.tabid   = idx.tabid AND
   con.tabid   = col.tabid AND
   con.idxname = idx.idxname
   AND 
   (
     col.colno = idx.part1  OR
     col.colno = idx.part2  OR
     col.colno = idx.part3  OR
     col.colno = idx.part4  OR
     col.colno = idx.part5  OR
     col.colno = idx.part6  OR
     col.colno = idx.part7  OR
     col.colno = idx.part8  OR
     col.colno = idx.part9  OR
     col.colno = idx.part10 OR
     col.colno = idx.part11 OR
     col.colno = idx.part12 OR
     col.colno = idx.part13 OR
     col.colno = idx.part14 OR
     col.colno = idx.part15 OR
     col.colno = idx.part16
   )
    AND
    tab.tabname = ? AND
    tab.owner   = ?
EOF

    $pk_sth->execute($table, $owner);
    
    my $column;

    $pk_sth->bind_columns(\$column);    

    while($pk_sth->fetch)
    {
      push(@columns, $column);
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
    require DBD::Informix::Metadata;

    $class = $self->class or die "Missing class!";

    my $db  = $self->db;  
    my $dbh = $db->dbh or die $db->error;

    # We need the table id.  To get it, we need the "owner" name.  Asking
    # for column information is the only way I know of to reliably get
    # this information.
    #
    # Informix does not support DBI's column_info() method so we have
    # to get all that into "the hard way."
    #
    # Each item in @col_list is a reference to an array of values:
    #
    #   0     owner name
    #   1     table name
    #   2     column number
    #   3     column name
    #   4     data type (encoded)
    #   5     data length (encoded)
    #
    my @col_list = DBD::Informix::Metadata::ix_columns($dbh, $self->table);

    # Here's the query for the table id
    my $st_sth = $dbh->prepare(<<"EOF");
SELECT tabid FROM informix.systables WHERE tabname = ? AND owner = ?
EOF

    # Take the info from the first column (arbitrarily selected)
    #                table name       owner name
    $st_sth->execute($col_list[0][1], $col_list[0][0]);
    my $table_id = $st_sth->fetchrow_array;

    unless(defined $table_id)
    {
      die "Could not find informix.systables record for table ",
          "'$col_list[0][1]' with owner '$col_list[0][0]'";
    }

    # Then comes this monster query to get the unique key column names.
    # (The subquery fithers out any primary keys.) I'd love to know a
    # better/easier way to do this...
    my $uk_sth = $dbh->prepare(<<'EOF');
SELECT
  col.colname,
  idx.idxname
FROM
  informix.sysindexes idx, 
  informix.syscolumns col
WHERE
  idx.tabid   = ?   AND 
  idx.idxtype = 'U' AND 
  idx.tabid   = col.tabid
  AND 
  (
    col.colno = idx.part1 OR
    col.colno = idx.part2 OR
    col.colno = idx.part3 OR
    col.colno = idx.part4 OR
    col.colno = idx.part5 OR
    col.colno = idx.part6 OR
    col.colno = idx.part7 OR
    col.colno = idx.part8 OR
    col.colno = idx.part9 OR
    col.colno = idx.part10 OR
    col.colno = idx.part11 OR
    col.colno = idx.part12 OR
    col.colno = idx.part13 OR
    col.colno = idx.part14 OR
    col.colno = idx.part15 OR
    col.colno = idx.part16
  )
  AND NOT EXISTS
  (
    SELECT * FROM
      informix.sysconstraints con
    WHERE
      con.tabid      = ?   AND
      con.constrtype = 'P' AND
      con.idxname    = idx.idxname
  );
EOF

    $uk_sth->execute($table_id, $table_id);
    
    my($column, $key);

    $uk_sth->bind_columns(\$column, \$key);

    while($uk_sth->fetch)
    {
      my $uk = $unique_keys{$key} ||= 
        Rose::DB::Object::Metadata::UniqueKey->new(name => $key, parent => $self);

      $uk->add_column($column);
    }
  };

  if($@)
  {
    Carp::croak "Could not auto-retrieve unique keys for class $class - $@";
  }

  # This sort order is part of the API, and is essential to make the
  # test suite work.
  my @uk = map { $unique_keys{$_} } sort map { lc } keys(%unique_keys);

  return wantarray ? @uk : \@uk;
}

#
# Crazy Informix helper functions
#

# Helper functions from $INFORMIXDIR/etc/xpg4_is.sql
# http://www-306.ibm.com/software/data/informix/pubs/library/datablade/dbdk/sqlr/01.fm50.html
#
# In call cases, the "coltype" argument is replaces with the already-
# adjusted $type_num, so ignore the subtraction of 256 in all of the
# pasted code.

# create procedure 'informix'.ansinumprec(coltype smallint, collength smallint)
# returning int;
# 
#         { FLOAT and SMALLFLOAT precisions are in bits }
# 
#         if (coltype >= 256) then
#             let coltype = coltype - 256;
#         end if;
# 
#         if (coltype = 1) then                           -- smallint
#             return 5;
#         elif (coltype = 2) or (coltype = 6) then        -- int
#             return 10;
#         elif (coltype = 3) then                         -- float
#             return 64;
#         elif (coltype = 4) then                         -- smallfloat
#             return 32;
#         elif (coltype = 5) or (coltype = 8) then        -- decimal
#             return (trunc(collength / 256));
#         else
#             return NULL;
#         end if;
# end procedure
# document
#         'returns the precision of a numeric column',
#         'Synopsis: ansinumprec(smallint, smallint) returns int';
        
sub _ix_numeric_precision
{
  my($type_num, $collength) = @_;

  if(exists $Numeric_Precision{$type_num})
  {
    return $Numeric_Precision{$type_num};
  }

  if($type_num == DECIMAL || $type_num == MONEY)
  {
    return int($collength / 256);
  }
  
  return undef;
}

# create procedure 'informix'.ansinumscale(coltype smallint, collength smallint)
# returning int;
# 
#   if (coltype >= 256) then
#       let coltype = coltype - 256;
#   end if;
# 
#   if (coltype = 1) or (coltype = 2) or 
#      (coltype = 6) then
#       return 0;
#   elif (coltype = 5) or (coltype = 8) then
#       return (collength - ((trunc(collength / 256))*256));
#   else
#       return NULL;
#   end if;
# end procedure
# document
#   'returns the scale of a numeric column',
#   'Synopsis: ansinumscale(smallint, smallint) returns int';

sub _ix_numeric_scale
{
  my($type_num, $collength) = @_;
  
  if($type_num == SMALLINT || $type_num == INTEGER ||
     $type_num == SERIAL)
  {
    return 0;
  }
  
  if($type_num == DECIMAL || $type_num == MONEY)
  {
    return $collength - ((int($collength / 256)) * 256);
  }
  
  return undef;
}

# create procedure 'informix'.ansinumprecradix( coltype smallint)
# returning int;
# 
# 	if (coltype >= 256) then
# 	    let coltype = coltype - 256;
# 	end if;
# 
# 	if (coltype = 1) or (coltype = 2) or 
# 	   (coltype = 5) or (coltype = 6) or
# 	   (coltype = 8) then
# 	    return 10;
# 	elif (coltype = 3) or (coltype = 4) then
# 	    return 2;
# 	else
# 	    return NULL;
# 	end if;
# end procedure
# document
# 	'returns the precision radix of a numeric column',
# 	'Synopsis: ansinumprecradix(smallint) returns int';

sub _ix_numeric_precision_radix
{
  my($type_num, $collength) = @_;
  
  if($type_num == SMALLINT || $type_num == INTEGER ||
     $type_num == DECIMAL  || $type_num == SERIAL  ||
     $type_num == MONEY)
  {
    return 10;
  }
  
  if($type_num == FLOAT || $type_num == SMALLFLOAT)
  {
    return 2;
  }
  
  return undef;
}

# create procedure 'informix'.ansimaxlen(coltype smallint, collength smallint)
# returning int;
# 
#         if (coltype >= 256) then
#             let coltype = coltype - 256;
#         end if;
# 
#         if (coltype = 0) then
#             return collength;
#         elif (coltype = 13) or (coltype = 16) then
#             return (collength - (trunc(collength / 256))*256);
#         else
#             return NULL;
#         end if;
# end procedure
# document
#         'returns the maximum length of character oriented column',
#         'Synopsis: ansimaxlen(smallint, smallint) returns int';
        
sub _ix_max_length
{
  my($type_num, $collength) = @_;

  if($type_num == CHAR)
  {
    return $collength;
  }
  
  if($type_num == VARCHAR || $type_num == NVARCHAR)
  {
    return $collength - (int($collength / 256)) * 256;
  }

  return undef;
}

# create procedure 'informix'.ansidatprec(coltype smallint, collength smallint)
# returning int;
# 
#   { if the column is nullable then coltype = coltype+256 }
# 
#   if (coltype = 7 or coltype = 263) then
#       return 0;
#   elif (coltype = 10 or coltype = 266) then
#       let collength = collength - 16*trunc(collength/16) - 10;
#       if (collength > 0) then
#       return collength;
#       else
#       return 0;
#       end if;
#   else
#       return NULL;
#   end if;
# end procedure
# document
#   'returns the date precision for a datetime column',
#   'Synopsis: ansidatprec(smallint, smallint) returns int';

# Don't seem to need this...
# sub _ix_datetime_precision
# {
#   my($type_num, $collength) = @_;
#   
#   if($type_num == DATE)
#   {
#     return 0;
#   }
#   
#   if($type_num == DATETIME)
#   {
#     $collength = $collength - (16 * int($collength / 16)) - 10;
#     
#     if($collength > 0)
#     {
#       return $collength;
#     }
#     
#     return 0;
#   }
#   
#   return undef;
# }

# For columns of type DATETIME or INTERVAL, collength is determined using
# the following formula:
# 
# (length * 256) + (largest_qualifier_value * 16) + smallest_qualifier_value
# 
# The length is the physical length of the DATETIME or INTERVAL field, and
# largest_qualifier and smallest_qualifier have the values shown in the
# following table.
#
# Field Qualifier   Value
# YEAR                 0
# MONTH                2
# DAY                  4
# HOUR                 6
# MINUTE               8
# SECOND              10
# FRACTION(1)         11
# FRACTION(2)         12
# FRACTION(3)         13
# FRACTION(4)         14
# FRACTION(5)         15
#
# For example, if a DATETIME YEAR TO MINUTE column has a length of 12
# (such as YYYY:DD:MM:HH:MM), a largest_qualifier value of 0 (for YEAR),
# and a smallest_qualifier value of 8 (for MINUTE), the collength value is
# 3080, or (256 * 12) + (0 * 16) + 8.
#
# The above is all just a fancy way of saying:
#
# largest_qualifier_value  = collength & 0xF0
# smallest_qualifier_value = collength & 0xF
#

sub _ix_datetime_specific_type
{
  my($type_num, $collength) = @_;

  return  unless($type_num == DATETIME);
  
  my $largest_qualifier  = $collength & 0xF0;
  my $smallest_qualifier = $collength & 0xF;

  unless(exists $Datetime_Qualifiers{$largest_qualifier} &&
         exists $Datetime_Qualifiers{$smallest_qualifier})
  {
    die "No datetime qualifier(s) found for collength $collength";
  }

  return "datetime $Datetime_Qualifiers{$largest_qualifier} to $Datetime_Qualifiers{$smallest_qualifier}";
}

1;
