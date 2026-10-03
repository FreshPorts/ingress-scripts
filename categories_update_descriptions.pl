#!/usr/local/bin/perl -w 

#
# $Id: categories_update_descriptions.pl,v 1.3 2007-10-11 18:14:38 dan Exp $
#
# Copyright (c) 2007-2026 Dan Langille
#

#use 5.006;
use warnings;
use strict;
use FreshPorts::category;
use DBI;
use FreshPorts::database;
use FreshPorts::utilities;
use FreshPorts::constants;

my $dbh;
my $sql;
my $sth;
my @row;

use Text::CSV_XS;  # textproc/p5-Text-CSV_XS

# = for testing
use Data::Dumper;

FreshPorts::Utilities::InitSyslog();

$dbh = FreshPorts::Database::GetDBHandle();


my @Categories = parse_categories(shift);
#print Dumper [@Categories];
# = end of test

update_each_category($dbh, @Categories);

$dbh->commit();
$dbh->disconnect();

sub update_each_category
{
  my $dbh        = shift;
  my @Categories = @_;
  
  my $category = FreshPorts::Category->new($dbh);

  foreach my $value (@Categories) {
#    print $value->{category} . "\n";
    $category->{name} = $value->{category};
    $category->{id}   = 0;
    if ($category->FetchByName()) {
#      print $category->{name} . ": old: " . $category->{description} . " new: ". 
#      $value->{description}. "\n";
      $category->{description} = $value->{description};
      $category->save();
    } else {
      FreshPorts::Utilities::ReportError('err', "Category found in file, not found in database: " . $value->{category}, 0);
    }
  }
}

# Input:  filename
# Output: an array of hashes representing categories,
#         each hash having fields named "category",
#         "description", and "class"
sub parse_categories
{
   my ($fn) = @_;

   open my $fh, "<", $fn or die "cannot open $fn: $!n";
   my $csv = Text::CSV_XS->new();
   my @r;
   while (<$fh>)
   {
      chomp;
      next if /^s*#/;
      next if /^s*$/;

      if ($csv->parse($_)) {
         my @c = $csv->fields;
         if (@c != 3) {
            warn "oops, got " . scalar(@c) . " fields at line $. while expecting 3n";
            next;
         }
         push @r, {
            category    => $c[0],
            description => $c[1],
            class       => $c[2],
         };
      } else {
         warn "oops, cannot parse line $.n";
      }
   }
   close $fh;
   return @r;
}

