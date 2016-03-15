package RDSBackup::DB;
use strict;
use warnings;
use Storable qw{ store retrieve };
use Moose;

use Data::Dumper;
=head2

dbfile -- Getter/Setter for path to DB file, defaults to "./RDSBackup.db"

=cut

has dbfile 	=> (isa => 'Str', is => 'rw', default => "./RDSBackup.db");
has _db 	=> (isa => 'HashRef[Paws::RDS::DBSnapshot]', is => 'rw');
has _error	=> (isa => 'ArrayRef[Str]', is => 'rw', default => sub { []; });

=head2

create -- Creates DB if it doesn't exist, loads it from disk if it does.

=cut

sub create {
	my ($self,$db) = @_;
		unless ( defined $self->_db ) {
		unless (-f $self->dbfile ) {
			my %hash;
			$self->_db(\%hash);
			$self->storeDB;
		}
		eval {
			my $db = retrieve($self->dbfile);
			$self->_db($db);
		} or do {
			$self->error("Unable to retrieve DB file: ".$@ );
			return;
		};
	}
	if ( defined $db ) {
		$self->_db($db);
		$self->storeDB;
	}
	return 1;
}

=head2

fetchAll -- Fetches all entries from DB

=cut

sub fetchAll {
	my $self = shift;
	unless ( defined $self->_db ) {
		unless ( $self->create ) {
			return;
		}
	}
	return $self->_db;
}

=head2

storeDB -- Writes DB out to disk

=cut

sub storeDB {
	my $self = shift;
	eval {
		store $self->fetchAll, $self->dbfile;
	} or do {
		$self->error("Unable to store DB:".$@);
		return;
	};
	return 1;
}

=head2

snapshotID -- Set and Retrieve snapshots by id from DB

=cut

sub snapshotID {
	my ($self,$id,$data) = @_;
	if ( defined $data ) {
		my $db = $self->fetchAll;
		$db->{$id} = $data;
		$self->create($db);
	}
	if ( defined $self->fetchAll ) {
		return $self->fetchAll->{$id};
	}
	$self->error('DB is not defined.');
	return;
}

=head2

snapshotIDDelete -- Remove snapshot from DB

=cut

sub snapshotIDDelete {
	my ($self,$id) = @_;
	my $db = $self->fetchAll;
	delete $db->{$id};
	$self->create($db);
	return 1;
}



=head2

error -- Collects errors for object

=cut


sub error {
	my ($self,$msg) = @_;
	if (defined $msg) {
		my @errors = @{ $self->_error };
		push @errors, $msg;
		$self->_error(\@errors);
	}
	return $self->_error;
}


sub DEMOLISH {
	my $self = shift;
	$self->storeDB;
}

1;