#!/usr/bin/perl
#
# Version 0.2 - Copyright (c) 2011-2012 by RevoGirl
# Version 0.5 - Copyright (c) 2013 by Pike R. Alpha (PikeRAlpha@yahoo.com)
#
# Updates:
#			- Header output added (Pike, October 2013)
#			- Improved header with (flexible) script version and current year (Pike, October 2014)
#			- Reading target folder instead of using hardcoded filenames (Pike, May 2014)
#			- Target volume support added (Pike, June 2014)
#

use Time::Piece;

my $gScriptVersion = "0.5";

my $gTargetVolume = "/"; # Example: Volumes/Yosemite

#-------------------------------------------------------------------------------

sub readPacket
{
	my $targetPath = $_[0];
	my $targetFile = $_[1];
	$targetFile = sprintf("%s%s", $targetPath, $targetFile);
	#printf("TargetFile: %s\n", $targetFile);

	my $targetFolder = $_[1];
	mkdir "$targetFolder", 0777 unless -d "$targetFolder";

	if (open(IN, $targetFile))
	{
		binmode IN;
		my ($bytesRead, $data, $efiRevision, $offset, $imageSize);
		my $packedItems = 0;
		my $currentItem = 0;

		if (($bytesRead = read(IN, $data, 2)) > 0)
		{
			$efiRevision = unpack("n", reverse($data));

			printf("EFI revision: %d\n", $efiRevision);
		}

		if (($bytesRead = read(IN, $data, 2)) > 0)
		{
			$packedItems = unpack("n", reverse($data));

			printf ("Number of packed images: %d\n", $packedItems);
		}

		my $index = 4;
		my $headerLength = $index + (($packedItems + 1) * 72);

		printf("Header length: %d\n\n", $headerLength);

		while ($currentItem < $packedItems)
		{
			my $filename = "";
			my $imageData = "";
			$imageSize = 0;

			seek (IN, $index, 0);

			if (($bytesRead = read(IN, $data, 64)) > 0)
			{
				my @array = split(/\0/, $data, 2);
				$filename = @array[0];
				$index += $bytesRead;
				printf("Image(%d): %s ", $currentItem, $filename);
			}

			if (($bytesRead = read(IN, $data, 4, $index)) > 0)
			{
				$index += $bytesRead;
				$offset = unpack("N", reverse($data));

				printf("(offset: %d/0x%x, ", $offset, $offset);
			}

			if (($bytesRead = read(IN, $data, 4, $index)) > 0)
			{
				$index += $bytesRead;
				$imageSize = unpack("N", reverse($data));

				printf("size: %d/0x%x) ", $imageSize, $imageSize);
			}

			seek (IN, $offset, 0);

			if (($imageBytesRead = read(IN, $imageData, $imageSize)) > 0)
			{
				#printf("ImageDataRead: %d\n", $imageBytesRead);
				printf("Read: %d\n", length($imageData));
			}

			seek (IN, $index, 0);

			open(OUT, ">$targetFolder/$filename") || die $!;
			binmode OUT;
			print OUT $imageData;

			close(OUT);

			$currentItem++;
		}

		printf ("\n");
		close (IN);
	}
	else
	{
		printf ("Error!\n");
	}
}

#-------------------------------------------------------------------------------

sub main()
{
	#
	# Clear screen and move cursor position to 0,0
	#
	print ("\033[2J\033[0;0H");
	printf ("\nefires-xtract v0.2 Copyright (c) 2011-2012 by † RevoGirl\n");
	printf ("              v$gScriptVersion Copyright (c) 2013-%d by Pike R. Alpha\n", localtime->strftime('%Y'));
	printf ("-----------------------------------------------------------\n");

	my $path = "$gTargetVolume/usr/standalone/i386/EfiLoginUI/";

	opendir(DIR, $path) or die $!;
	
	while (my $file = readdir(DIR))
	{
		# We only want files
		next unless (-f "$path/$file");
		
		# Use a regular expression to find files ending in .efires
		next unless ($file =~ m/\.efires$/);
		
		print "Filename: $file\n";

		readPacket($path, $file);
	}

	closedir(DIR);
}

#-------------------------------------------------------------------------------

main();
exit(0);
