package RDSBackup::AWS;
use strict;
use warnings;
use Paws;
use Date::Parse qw{str2time};
use POSIX qw(strftime);
use Data::Dumper;
use Moose;


=head2

region -- Getter/Setter for AWS region, defaults to "us-east-1"

=cut

has region	=> (isa => 'Str', is => 'rw', default => "us-east-1");

=head2

dbid -- Getter/Setter for RDS DB Identifier

=cut

has dbid    => (isa => 'Str', is => 'rw');

has _rds 	=> (isa => 'Paws::RDS', is => 'rw');
has _error	=> (isa => 'ArrayRef[Str]', is => 'rw', default => sub { []; });


=head2

createSnapshot -- Creates new AWS Snapshot and logs it in DB

=cut

sub createSnapshot {
	my $self = shift;
	my $snapshot;
	my $date = strftime "%Y-%b-%e-%H-%M", gmtime;
	my $DBInstanceIdentifier = $self->dbid;
	my $DBSnapshotIdentifier = "RDSBackup-$DBInstanceIdentifier-$date";
	eval {
		$snapshot = $self->rds->CreateDBSnapshot( 
		 	DBInstanceIdentifier => $DBInstanceIdentifier,
		 	DBSnapshotIdentifier => $DBSnapshotIdentifier, 
		);
	} or do {
		$self->error("createSnapshot failed -- Unable to create Snapshot: ".$@);
		return;
	};
	return $snapshot;
}

=head2

deleteSnapshot -- Removes a Snapshot from AWS and the DB

=cut

sub deleteSnapshot {
	my ($self,$id) = @_;
	return unless defined $id;
	eval {
		printf "Removing snapshot %s\n", $id;
		$self->rds->DeleteDBSnapshot( DBSnapshotIdentifier => $id);
	} or do {
		$self->error("Unable to create Snapshot:".$@ );
		return;
	};
	return 1;	
}

=head2

getSnapshotsFromAWS -- Gets a list of all manual snapshots in AWS for our dbid

=cut

sub getSnapshotsFromAWS {
	my $self = shift;
	my $snapshotmsg;
	eval {
		$snapshotmsg = $self->rds->DescribeDBSnapshots(SnapshotType => "manual");
	} or do {
		$self->error("Failed to describe snapshots:".$@);
		return;
	};
	my @snapshots = @{ $snapshotmsg->DBSnapshots };

	# Filter list to only snapshots for our dbid
	my @mySnapshots;
	if ($#snapshots >= 1) {
		@mySnapshots = grep { $_->DBInstanceIdentifier eq $self->dbid; } @snapshots;
	}
	return \@mySnapshots;

}

=head2

rds -- Paws::RDS

=cut

sub rds {
	my ($self,$rds) = @_;
	if (defined $rds) {
		$self->_rds($rds);
	}
	unless ( defined $self->_rds ) {
		my $rds = Paws->service('RDS', region => $self->region);
		$self->_rds($rds);
	}
	return $self->_rds;
}



sub error {
	my ($self,$msg) = @_;
	if (defined $msg) {
		my @errors = @{ $self->_error };
		push @errors, $msg;
		$self->_error(\@errors);
	}
	return $self->_error;
}




1;