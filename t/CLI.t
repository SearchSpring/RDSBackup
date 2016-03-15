#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::MockObject;
use Paws;
use Paws::RDS::DBSnapshot;
use Paws::RDS::DBSnapshotMessage;
use Paws::RDS::CreateDBSnapshotResult;
use Paws::RDS::DeleteDBSnapshotResult;
use Find::Lib '../lib' => 'RDSBackup::CLI';
use RDSBackup::CLI;

use Data::Dumper;


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
	CreateDBSnapshot => sub { Paws::RDS::CreateDBSnapshotResult->new(DBSnapshot => $DBSnapshot) },
	DeleteDBSnapshot => sub { Paws::RDS::DeleteDBSnapshotResult->new(DBSnapshot => $DBSnapshot) },
	DescribeDBSnapshots => sub { $DBSnapshotMessage },
	new => sub { bless {}, 'Paws::RDS' },
);
my $fakerds = Paws::RDS->new();


# Location of DB file
my $dbfile = "/tmp/RDSBackupTest.db";

# Test run
{
	my $cli = RDSBackup::CLI->new(dbfile => $dbfile, dbid => "1");
	$cli->rds($fakerds);
	my $db = $cli->fetchAll;
	is_deeply($db,{},'run -- expected $db to be {}.');
	$cli->run;
	is_deeply($cli->error,[],'run -- expected error after run call to be empty.');
	my $mySnapshots = $cli->getSnapshotsFromAWS;
	is_deeply($mySnapshots,[$DBSnapshot,$DBSnapshot2],'run -- expected $mySnapshots to be [$DBSnapshot,$DBSnapshot2].');
	$cli->snapshotID(1,$DBSnapshot);
	is_deeply($cli->fetchAll, { "1" => $DBSnapshot }, 'run -- expected to see 1 snapshot in db.');
	is_deeply($cli->error,[],'run -- expected error after getSnapshotsFromAWS call to be empty.');
}

unlink $dbfile or die($!);
# Test lastXSnaps
{
	my $cli = RDSBackup::CLI->new(dbfile => $dbfile, dbid => "1", keep => 1);
	$cli->rds($fakerds);
	$cli->snapshotID(1,$DBSnapshot);
	$cli->snapshotID(2,$DBSnapshot2);
	my $keep = $cli->lastXSnaps;
	is_deeply($keep,[$DBSnapshot2],'lastXSnaps -- expected $keep to be [$DBSnapshot2].');
	is_deeply($cli->error,[],'lastXSnaps -- expected error after lastXSnaps call to be empty.');
	is($#{$keep}+1,$cli->keep,'lastXSnaps -- expected $keep to be $cli->keep.');
}
unlink $dbfile or die($!);
# Test snapsToDelete
{
	my $cli = RDSBackup::CLI->new(dbfile => $dbfile, dbid => "1", keep => 1);
	$cli->rds($fakerds);
	$cli->snapshotID(1,$DBSnapshot);
	$cli->snapshotID(2,$DBSnapshot2);
	my $delete = $cli->snapsToDelete;
	is_deeply($delete,[$DBSnapshot],'snapsToDelete -- expected $delete to be [$DBSnapshot2].');
	is_deeply($cli->error,[],'snapsToDelete -- expected error after snapsToDelete call to be empty.');
}
unlink $dbfile or die($!);
# Test error
{
	my $cli = RDSBackup::CLI->new(dbfile => $dbfile, dbid => "1", keep => 1);
	my $error = 'This is a test.';
	$cli->error($error);
	my $errors = $cli->error;
	is_deeply($errors,[$error],'error -- expected error to return [$error].');	

}
unlink $dbfile or die($!);
done_testing();
