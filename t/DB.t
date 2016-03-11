#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Paws::RDS::DBSnapshot;
use Find::Lib '../lib' => 'RDSBackup::CLI';
use RDSBackup::DB;

use Data::Dumper;

# Location of DB file
my $dbfile = "/tmp/RDSBackupTest.db";

# create
{
	my $db = RDSBackup::DB->new(dbfile => $dbfile);
	is($db->create,1,'create -- expected create to return 1.');
	my $snapshot = Paws::RDS::DBSnapshot->new;
	my $newdb = $db->fetchAll;
	$newdb->{1} = $snapshot;
	is($db->create($newdb),1,'create -- expected create with arg to return 1.');
	my $returndb = $db->fetchAll;
	is($returndb,$newdb,'create -- expected $returndb to be $newdb.');
	is_deeply($db->error,[],'create -- expected error after create call to be empty.');
}
unlink $dbfile or die($!);

# Test fetchall
{
	my $db = RDSBackup::DB->new(dbfile => $dbfile);
	is_deeply($db->fetchAll,{},'fetchAll -- expected method fetchAll to return empty hash.' );
	is_deeply($db->error,[],'fetchAll -- expected error after fetchAll call to be empty.');
}
unlink $dbfile or die($!);
# Test storeDB
{
	my $db = RDSBackup::DB->new(dbfile => $dbfile);
	$db->storeDB();
	is_deeply($db->error,[],'storeDB -- expected error after storeDB to be empty.');
	is_deeply($db->error,[],'storeDB -- expected error after storeDB call to be empty.');
}
unlink $dbfile or die($!);
# Test snapshotID
{
	my $db = RDSBackup::DB->new(dbfile => $dbfile);
	my $id = $db->snapshotID(5);
	is($id,undef,'snapshotID -- expected null result from method snapshotID');
	my $snapshot = Paws::RDS::DBSnapshot->new( DBSnapshotIdentifier => "1");
	$id = $db->snapshotID(1,$snapshot);
	ok($id->DBSnapshotIdentifier eq $snapshot->DBSnapshotIdentifier,"snapshotID -- expected snapshotsID to return a Paws::RDS::DBSnapshot.");
	is_deeply($db->error,[],'snapshotID -- expected error after snapshotID call to be empty.');
}
unlink $dbfile or die($!);
# Test snapshotIDDelete
{
	my $db = RDSBackup::DB->new(dbfile => $dbfile);
	my $snapshot = Paws::RDS::DBSnapshot->new( DBSnapshotIdentifier => "1");
	$db->snapshotID(1,$snapshot);
	my $snap = $db->snapshotID(1);
	is_deeply($snap,$snapshot,'snapshotIDDelete -- expected $snap to be $snapshot.');
	$db->snapshotIDDelete(1);
	$snap = $db->snapshotID(1);
	is($snap,undef,'snapshotIDDelete -- expected $snap to be undef.');
	is_deeply($db->error,[],'snapshotIDDelete -- expected error after snapshotIDDelete call to be empty.');
}
unlink $dbfile or die($!);

done_testing();
