#!/usr/bin/perl -w
#
# $Id:extractAspects.pl$
#
# Script for extracting the names of aspects used by OPLog
#
use strict;
use File::Find;
use Getopt::Long;
use Data::Dumper;

my $outputDir;

GetOptions(
           'outputdir=s'        => \$outputDir
          );


my $cacheFile = "OPL-Configuration.cached";
$cacheFile = "$outputDir/$cacheFile" if $outputDir;
my $outputFile = "OPL-Configuration.plist";
$outputFile = "$outputDir/$outputFile" if $outputDir;


my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$cacheMTime,$ctime,$blksize,$blocks) = stat $cacheFile;
$cacheMTime = -1 unless defined $cacheMTime;

my $cache = readCacheFile($cacheFile);


my @files;
find(\&addModifiedSourceFiles, @ARGV);

foreach my $file (@files) {
    delete $cache->{$file};
}


# extract domains and aspects from all files found (i.e. do not use definitions from removed files)
my $allDomains;
my $allAspects;
while (my ($file, $dict) = each %$cache) {
    while (my ($key, $value) = each %{$dict->{'domains'}}) {
        $allDomains->{$key} = $value;
    }
    while (my ($key, $value) = each %{$dict->{'aspects'}}) {
        $allAspects->{$key} = $value;
    }
}


foreach my $filename (@files) {
    print "Parsing $filename...\n";
    
    my ($domains, $aspects) = scanFile($filename);
    $cache->{$filename}{'domains'} = $domains if defined $domains;
    $cache->{$filename}{'aspects'} = $aspects if defined $aspects;
    
    while (my ($key, $value) = each %$aspects) {
        
        if (exists $allAspects->{$key}) {
            next if $allAspects->{$key} == $value;
            
            warn "Different values for aspect $key found! ($allAspects->{$key} vs. $value)\n";
        }
        
        $allAspects->{$key} = $value;
    }
    
    while (my ($key, $value) = each %$domains) {
        
        if (exists $allDomains->{$key}) {
            next if $allDomains->{$key} eq $value;
            
            warn "Different values for domain $key found! ($allDomains->{$key} vs. $value)\n";
        }
        
        $allDomains->{$key} = $value;
    }
}

writeCacheFile($cacheFile, $cache);

writePlist($allDomains, $allAspects, $outputFile);

exit 0;



sub addModifiedSourceFiles {
    
    return if $_ !~ /\.[mh]$/;
    return if -d $_;
    return if $File::Find::name =~ m|^\./build|; # TODO: improve build dir detection
    
    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($_);
    
    push @files, $File::Find::name if $mtime > $cacheMTime;
}


sub scanFile {
    my $filename = shift @_;
    
    my $file = readFile($filename);
    
    $file =~ s/\r\n/\n/g;      # unify line ends
    $file =~ s/\\\n/ /g;       # join continued lines
    $file =~ s|/\*.*?\*/| |gs; # remove /* */ comments
    $file =~ s|//.*$|\n|gm;    # remove // comments
    
    my (@aspects) = ($file =~ /^[ \t]*#[ \t]*define[ \t]+(\w+)[ \t]+OPL_ASPECT[ \t]+(\S.*?)[ \t]*$/gm);
    my (@domains) = ($file =~ /^[ \t]*#[ \t]*define[ \t]+(\w+)[ \t]+OPL_DOMAIN[ \t]+\@"(\S.*?)"[ \t]*$/gm);
    
    my $aspects;
    while (@aspects) {
        my $key = shift @aspects;
        my $value = shift @aspects;
        
        $value =~ s/^\s*((?:\d+|0x[0-9A-F]+))L?\s*$/$1/i; # remove 'L' after number
        
        if ($value =~ /^\s*0x[0-9A-F]+\s*$/i) {
            $value = hex($value);
        }
        elsif ($value =~ /^\s*-?\d+\s*$/i) {
            $value = int $value;
        }
        else {
            warn "Ignoring value for aspect '$key' ($value isn't numeric)!\n";
            next;
        }
        
        if ($aspects) {
            if (exists $aspects->{$key}) {
                warn "Different values for aspect $key found! ($aspects->{$key} vs. $value)\n"
                    unless $aspects->{$key} == $value;
            }
        }
        
        $aspects->{$key} = $value;
    }
    
    my $domains;
    while (@domains) {
        my $key = shift @domains;
        my $value = shift @domains;
        
        if ($domains) {
            if (exists $domains->{$key}) {
                warn "Different values for domain $key found! ($domains->{$key} vs. $value)\n"
                    unless $domains->{$key} == $value;
            }
        }
        
        $domains->{$key} = $value;
    }
    
    return ($domains, $aspects);
}


sub readFile {
    my $filename = shift @_;
    my $file;
    
    open FH, "<$filename" or die "ERROR: Could not open file $filename! ($!)\n";
    {
        local $/ = undef;
        $file = <FH>;
    }
    close FH;
    
    return $file;
}


sub readCacheFile {
    my $filename = shift @_;
    
    return {} unless -e $filename;
    
    my $cacheContent = readFile($filename);
    my $cache = eval $cacheContent;
    
    return $cache;
}


sub writeCacheFile {
    my $filename = shift @_;
    my $cache = shift @_;
    
    open FH, ">$filename" or die "Could not open cache file $filename for writing! ($!)\n";
    print FH Data::Dumper->Dump([$cache], ["cache"]);;
    close FH;
}




sub writePlist {
    my $domains = shift @_;
    my $aspects = shift @_;
    my $filename = shift @_;
    
    open FH, ">$filename" or die "Couldn't open output file '$filename'! ($!)\n";
    
    print FH <<PLISTHEAD;
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>domains</key>
    <dict>
PLISTHEAD
    
    while (my ($key, $value) = each %$domains) {
	    print FH "        <key>$key</key>\n";
	    print FH "        <string>$value</string>\n";
    }
    
    print FH <<PLISTSWITCHDICT;
    </dict>
    <key>aspects</key>
    <dict>
PLISTSWITCHDICT
    	
    while (my ($key, $value) = each %$aspects) {
	    print FH "        <key>$key</key>\n";
	    print FH "        <integer>$value</integer>\n";
    }
    	
print FH <<PLISTTAIL;
    </dict>
</dict>
</plist>
PLISTTAIL
    
    close FH;
}

