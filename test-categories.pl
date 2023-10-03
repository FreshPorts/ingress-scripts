#!/usr/local/bin/perl -w

require FreshPorts::config;
require FreshPorts::categories;

use List::MoreUtils 'any';

my $category_name = 'shells';

FreshPorts::categories::FetchAll();

if ( any {/$category_name/} @FreshPorts::Categories::categories ) {
  print "match found\n";
} else {
  print "nothing found\n";
}

if ( any {/$category_name/} @FreshPorts::Categories::categories ) {
  print "match found\n";
} else {
  print "nothing found\n";
}

if ( any {/$category_name/} @FreshPorts::Categories::categories ) {
  print "match found\n";
} else {
  print "nothing found\n";
}

#print @FreshPorts::Categories::categories;