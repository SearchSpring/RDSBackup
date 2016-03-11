#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::MockObject;
use Paws;
use Paws::RDS::DBSnapshot;
use Paws::RDS::DBSnapshotMessage;
use Find::Lib '../lib' => 'RDSBackup::CLI';
use RDSBackup::AWS;

## Fake RDS
my $mockrds = Test::MockObject->new();
my $DBSnapshot = Paws::RDS::DBSnapshot->new( 
	DBInstanceIdentifier => "1", 
	DBSnapshotIdentifier => "1",
	SnapshotCreateTime => "2014-07-14T03:36:45.210Z",
);
my $DBSnapshot2 = Paws::RDS::DBSnapshot->new( 
	DBInstanceIdentifier => "1", 
	DBSnapshotIdentifier => "2",
	SnapshotCreateTime => "2014-08-14T03:36:45.210Z",
);
my $DBSnapshotNotMine = Paws::RDS::DBSnapshot->new( 
	DBInstanceIdentifier => "2", 
	DBSnapshotIdentifier => "2",
	SnapshotCreateTime => "2014-09-14T03:36:45.210Z",
);
my $DBSnapshotMessage = Paws::RDS::DBSnapshotMessage->new( 
	DBSnapshots => [ $DBSnapshot, $DBSnapshotNotMine, $DBSnapshot2 ],
);
$mockrds->fake_module('Paws::RDS',
	CreateDBSnapshot => sub { $DBSnapshot },
	DeleteDBSnapshot => sub { $DBSnapshot },
	DescribeDBSnapshots => sub { $DBSnapshotMessage },
	new => sub { bless {}, 'Paws::RDS' },
);
my $fakerds = Paws::RDS->new();

# Location of DB file
my $dbfile = "/tmp/RDSBackupTest.db";

# Test createSnapshot
{
	my $aws = RDSBackup::AWS->new(dbid => "1");
	$aws->rds($fakerds);
	my $snap = $aws->createSnapshot();
	is_deeply($snap,$DBSnapshot,'createSnapshot -- expected $snap to be $DBSnapshot.');
	is_deeply($aws->error,[],'createSnapshot -- expected error after createSnapshot call to be empty.');
}
# Test deleteSnapshot
{
	my $aws = RDSBackup::AWS->new(dbid => "1");
	$aws->rds($fakerds);
	my $snapcreated = $aws->createSnapshot();
	my $snapdeleted = $aws->deleteSnapshot(1);
	is($snapdeleted,1,'deleteSnapshot -- expected $snapdeleted to be 1.');
	is_deeply($aws->error,[],'deleteSnapshot -- expected error after deleteSnapshot call to be empty.');
}
# Test getSnapshotsFromAWS
{
	my $aws = RDSBackup::AWS->new(dbid => "1");
	$aws->rds($fakerds);
	my $mySnapshots = $aws->getSnapshotsFromAWS;
	is_deeply($mySnapshots,[$DBSnapshot,$DBSnapshot2],'getSnapshotsFromAWS -- expected $mySnaphosts to be [$DBSnapshot].');
	is_deeply($aws->error,[],'getSnapshotsFromAWS -- expected error after getSnapshotsFromAWS call to be empty.');
}
# Test rds
{
	my $aws = RDSBackup::AWS->new(dbid => "1");
	my $rds = $aws->rds($fakerds);
	isa_ok($rds,'Paws::RDS', 'rds -- $rds' );
	is_deeply($aws->error,[],'rds -- expected error after rds call to be empty.');
}
# Test error
{
	my $aws = RDSBackup::AWS->new(dbid => "1");
	my $error = 'This is a test.';
	$aws->error($error);
	my $errors = $aws->error;
	is_deeply($errors,[$error],'error -- expected error to return [$error].');	
}
done_testing();
