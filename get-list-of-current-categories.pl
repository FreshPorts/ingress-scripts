#!/usr/local/bin/perl

my $categories_1line = `/usr/home/dan/scripts/get-list-of-current-categories.sh`;
chomp $categories_1line;
#print "'$categories_1line'\n";
my @categories = split / /, $categories_1line;
foreach my $category (@categories) {
  print "$category\n";
}
