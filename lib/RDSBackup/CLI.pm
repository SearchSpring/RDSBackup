package RDSBackup::CLI;
use strict;
use warnings;
use Getopt::Long;
use Date::Parse qw{str2time};
use Storable qw{ store retrieve };
use Data::Dumper;
use Moose;

extends 'RDSBackup::DB',
		'RDSBackup::AWS'
;

has keep 			=> (isa => 'Int', is => 'rw', default => 5);
has _error			=> (isa => 'ArrayRef[Str]', is => 'rw', default => sub { []; });
has _lastXSnaps 	=> (isa => 'ArrayRef[Paws::RDS::DBSnapshot]', is => 'rw');
has _snapsToDelete 	=> (isa => 'ArrayRef[Paws::RDS::DBSnapshot]', is => 'rw');


=head2

run -- Executes Snapshot and retention

=cut

sub run {
	my $self = shift;
	my $region = $self->region;
	my $dbid = $self->dbid;
	my $keep = $self->keep;
	my $dbfile = $self->dbfile;
	GetOptions (
		'region=s'	=> \$region,
		'dbid=s'	=> \$dbid,
		'keep=i'	=> \$keep,
		'dbfile=s'	=> \$dbfile,
	) or do {
		$self->error("Error in command line arguments\n");
		map { printf "%s\n", $_ } @{$self->error};
		return 1;
	};
	unless ($dbid) {
		$self->error("--dbid must be defined, cannot continue.");
		map { printf "%s\n", $_ } @{$self->error};
		return 1;
	}
	$self->region($region) if defined $region;
	$self->dbid($dbid);
	$self->keep($keep) if defined $keep;
	$self->dbfile($dbfile) if defined $dbfile;
	if ( @{ $self->error }[0] ) {
		print "Options parse Failures:\n";
		map { printf "%s\n", $_ } @{$self->error};
	}
	my $newsnap = $self->createSnapshot;
	if ( @{ $self->error }[0] ) {
		print "createSnapshot Failures:\n";
		map { printf "%s\n", $_ } @{$self->error};
		return 1;
	}
	my $DBSnapshot = $newsnap->DBSnapshot;
	$self->snapshotID($DBSnapshot->DBSnapshotIdentifier, $DBSnapshot);
	if ( @{ $self->error }[0] ) {
		print "Log snapshot Failures:\n";
		map { printf "%s\n", $_ } @{$self->error};
		return 1;
	}
	if ( defined $self->snapsToDelete ) {
		for my $snap (@{$self->snapsToDelete}) {
			$self->deleteSnapshot($snap->DBSnapshotIdentifier);
			$self->snapshotIDDelete($snap);
			if ( @{ $self->error }[0]) {
				print "Remove snapshot Failures:\n";
				map { printf "%s\n", $_ } @{$self->error};
				return 1;
			}
		}
	}
	$self->storeDB;
	if ( @{ $self->error }[0] ) {
		print "Store DB Failures:\n";
		map { printf "%s\n", $_ } @{$self->error};
		return 1;
	}
	return 0;
}

=head2

findSnapsInLog -- Match AWS snaps with snaps in log

=cut

sub findSnapsInLog {
	my $self = shift;
	my @return;
	map { 
		push @return, $_ if $self->snapshotID($_->DBSnapshotIdentifier) 
	} @{$self->getSnapshotsFromAWS};
	return \@return;
} 

=head2

lastXSnaps -- Returns the last $self->keep snapshots

=cut

sub lastXSnaps {
	my $self = shift;
	if ($self->keep < 1) {
		$self->error("Keep less than 1, unable to process.");
		return;
	}
	my @sorted;
	unless ( defined $self->_lastXSnaps ) {
		if ( $self->findSnapsInLog ) {
			my @snaps = grep {defined $_->SnapshotCreateTime } @{ $self->findSnapsInLog };
			@sorted = sort {
					str2time($b->SnapshotCreateTime) <=> str2time($a->SnapshotCreateTime); 
				} 
				@snaps
			;
		}
		if ($#sorted >= 1) {
			if ($#sorted+1 <= $self->keep) {
				$self->_lastXSnaps([@sorted]);
			}
			else {
				my $keep = $self->keep -1;
				$self->_lastXSnaps([ @sorted[0..$keep] ]);
				$self->_snapsToDelete([ @sorted[$keep+1..$#sorted] ]);
			} 
		}
	}
	return $self->_lastXSnaps;
}

=head2

snapsToDelete -- Returns snapshots to remove

=cut

sub snapsToDelete {
	my $self = shift;
	unless ( defined $self->_snapsToDelete ) {
		$self->lastXSnaps;
	}
	return $self->_snapsToDelete;
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