package Text::TEI::Collate::Lang::Armenian;

use strict;
use warnings;
use base qw/ Text::TEI::Collate::Lang /;
use utf8;
use Text::WagnerFischer::Armenian;
use vars qw( %PROPER_NAMES %ORTHOGRAPHY %SPELLINGS %PREFIXES %SUFFIXES 
			 @EXPORT_OK );

=head1 NAME

Text::TEI::Collate::Lang::Armenian - (Classical) Armenian language module for
Text::TEI::Collate

=head1 DESCRIPTION

This module is an extension of Text::TEI::Collate::Lang for the Armenian
language.  It also has some data hashes of orthographic and spelling
equivalence, which might be used for real at some point.

Also see documentation for Text::TEI::Collate::Lang.

=head1 METHODS

=cut

sub am_downcase {
	my $word = shift;
	my @letters = split( '', $word );
	my $out = '';
	foreach( @letters ) {
		if( $_ =~ /[\x{531}-\x{556}]/ ) {
			my $codepoint = unpack( "U", $_ );
			$codepoint += 48;
			$out .= pack( "U", $codepoint );
		} else {
			$out .= $_
		}
	}
	return $out;
}

=head2 canonizer

Get rid of the distinction between commas and semicolons, and get rid of
accent marks and hyphens, none of which were normalized in medieval times.
Also remove hyphens from extremely faithful transcriptions.

=cut

sub canonizer {
	my $word  = shift;

	# We don't really distinguish between commas and semicolons properly
	# in the manuscript.  Make them the same.
	$word =~ s/\./\,/g;

	# Get rid of accent marks.
	$word =~ s/՛//g;
	# Get rid of hyphen.
	$word =~ s/֊//g;
	# Get rid of any backtick that falls mid-word.
	$word =~ s/՝(.)/$1/g;

	return $word;
}

=head2 comparator

Lowercase the word, and get rid of some more orthographic distinctions
(aw vs long o; ew vs the ligature ew).

=cut

# The canonized word comes to us here.	We return a comparison string.
sub comparator {
	my $word = shift;

	# Standardize ligatures.
	$word =~ s/աւ/օ/g;	# for easy vocalic comparison to ո
	$word =~ s/և/եւ/g; 

	# Downcase the word.
	$word = am_downcase( $word );

	return $word;
}

=head2 distance

Use Text::WagnerFischer::Armenian::distance.

=cut

sub distance {
	return Text::WagnerFischer::Armenian::distance( @_ );
}

# What is coming to us here is the word after going through canonization.
sub print_word {
	my $word = shift;
	
	# Undo ligature contraction.
	$word =~ s/օ/աւ/g;	# because it is never wrong
	$word =~ s/եւ/և/g;	# likewise

	# Try to split into prefix/base/suffix.
	my( $pre, $base, $suf ) = split_word( $word );

	# Now try to find a canonical spelling.
	if( exists( $ORTHOGRAPHY{$base} ) ) {
		$base = $ORTHOGRAPHY{$base};
	} elsif( exists( $ORTHOGRAPHY{$pre.$base} ) ) {
		$base = $ORTHOGRAPHY{$pre.$base};
		$pre = '';
	} elsif( exists( $ORTHOGRAPHY{$base.$suf} ) ) {
		$base = $ORTHOGRAPHY{$base.$suf};
		$suf = '';
	} elsif( exists( $ORTHOGRAPHY{$pre.$base.$suf} ) ) {
		$base = $ORTHOGRAPHY{$pre.$base.$suf};
		$pre = $suf = '';
	}
	return "$pre$base$suf";

}


## Takes a word and splits off anything that looks like it might be a prefix or a suffix.
sub split_word {
	my $word = shift;
	my( $pre, $base, $suff );
	if( $word =~ /^([զյց])(.*)$/ ) {
		( $pre, $base ) = ( $1, $2 );
	} else {
		( $pre, $base ) = ( '', $word );
	}

	if( $base =~ /^(.*)([նդս])$/ ) {
		( $base, $suff ) = ( $1, $2 );
	} else {
		$suff = '';
	}

	return( $pre, $base, $suff );
}


## Data hashes

%PROPER_NAMES = ( 
	'պարսիկք' => 'Պարսիկք',
	'պարսից' => 'Պարսից',
	'պարսկաց' => 'Պարսկաց',
	'թուրքաց' => 'Թուրքաց',
	'քամայ' => 'Քամայ',
	'սատանայ' => 'Սատանայ',
	'հրէից' => 'Հրէից',
	'յովհաննէս' => 'Յովհաննէս',
	'հայոց' => 'Հայոց',
	'պետըրոս' => 'Պետրոս',
	'կոզեռն' => 'Կոզեռն',
	'աստուծոյ' => 'Աստուծոյ',
	'գրիգոր' => 'Գրիգոր',
	'մագիստրոսն' => 'Մագիստրոսն',
	'սարգիս' => 'Սարգիս',
	'վասակայ' => 'Վասակայ',
	'գըրիգոր' => 'Գրիգոր',
	'հայկազնեան' => 'Հայկազն',
	'մագիստըրոսն' => 'Մագիստրոսն',
	'մատթէոս' => 'Մատթէոս',
	'ուռհայեցի' => 'Ուռհայեցի',
	'յովհաննիսի' => 'Յովհաննիսի',
	'յովհաննիսէ' => 'Յովհաննիսէ',
	'հոռոմոց' => 'Հոռոմոց',
	'աստուած' => 'Աստուած',
	'մատթէոսի' => 'Մատթէոսի',
	'ուռհայեցւոյ' => 'Ուռհայեցւոյ',
	'պաւղոսի' => 'Պաւղոսի',
	'անտիոքայ' => 'Անտիոքայ',
	'բարսղի' => 'Բարսղի',
	'գրիգորիսի' => 'Գրիգորիսի',
	'քրիստոս' => 'Քրիստոս',
	'կոստանդնուպաւլիս' => 'Կոստանդնուպաւլիս',
	'նիկաւլայ' => 'Նիկաւլայ',
	'նիկոլայ' => 'Նիկաւլայ',
	'սիմէաւնի' => 'Սիմէաւնի',
	'միջագետաց' => 'Միջագետաց',
	'բելիարայ' => 'Բելիարայ',
	'յորդանան' => 'Յորդանան',
	'յուռհա' => 'Յուռհա',
	'քրիստոսի' => 'Քրիստոսի',
	'փռանկ' => 'Ֆռանգ',
	'ֆռանդ' => 'Ֆռանգ',
	'ֆռանկ' => 'Ֆռանգ',
	'ֆռանգ' => 'Ֆռանգ',
	'ֆռանկ' => 'Ֆռանգ',
	'փռանգ' => 'Ֆռանգ',
	'փռանկ' => 'Ֆռանգ',
	'վռանգ' => 'Ֆռանգ',
	'փռանգ' => 'Ֆռանգ',
	'փռանկք' => 'Ֆռանգք',
	'ֆռանդք' => 'Ֆռանգք',
	'ֆռանկք' => 'Ֆռանգք',
	'ֆռանգք' => 'Ֆռանգք',
	'ֆռանկք' => 'Ֆռանգք',
	'փռանգք' => 'Ֆռանգք',
	'փռանկք' => 'Ֆռանգք',
	'հռոմայեցւոց' => 'Հռոմայեցւոց',
	'ալէքսին' => 'Ալէքսին',
	'յունաց' => 'Յունաց',
	'գրիգորի' => 'Գրիգորի',
	'պաւղոս' => 'Պաւղոս',
	'ջահունից' => 'Ջահունից'
	);

%ORTHOGRAPHY = ( 
	'նըշան' => 'նշան',
	'իշխանդ' => 'իշխանք',
	'նըշանին' => 'նշանին',
	'այսըմ' => 'այսմ',
	'հըրէից' => 'հրէից',
	'սըրտիւ' => 'սրտիւ',
	'վարդապետըն' => 'վարդապետն',
	'ըզլոյսն' => 'ըզլոյսն',
	'մութըն' => 'մութն',
	'բըլուրք' => 'բլուրք',
	'հընչեցին' => 'հնչեցին',
	'ըզտղայս' => 'զտղայս',
	'գըտանէին' => 'գտանէին',
	'Յովհաննէս' => 'յովհաննէս',
	'Հայոց' => 'հայոց',
	'Հարցջիր' => 'հարցջիր',
	'քընընութիւնս' => 'քննութիւնս',
	'քըննութիւն' => 'քննութիւն',
	'հայրապետըն' => 'հայրապետն',
	'պետըրոս' => 'պետրոս',
	'Կոզեռն' => 'կոզեռն',
	'Աստուծոյ' => 'աստուծոյ',
	'Գրիգոր' => 'գրիգոր',
	'ԵՒ' => 'Եւ',
	'Կտակարանացն' => 'կտակարանացն',
	'Մագիստրոսն' => 'մագիստրոսն',
	'Սարգիս' => 'սարգիս',
	'Վասակայ' => 'վասակայ',
	'գընացին' => 'գնացին',
	'գըրիգոր' => 'գրիգոր',
	'ըզմեկնութիւն' => 'զմեկնութիւն',
	'կըտակարանացն' => 'կտակարանացն',
	'հայկազան' => 'հայկազնին',
	'հայկազնեան' => 'հայկազն',
	'մագիստըրոսն' => 'մագիստրոսն',
	'նըմանէ' => 'նմանէ',
	'արտասաւք' => 'արտասուաւք',
	'զըկուրծս' => 'զկուրծս',
	'Բացեալ' => 'բացեալ',
	'ըսկսաւ' => 'սկսաւ',
	'խորհըրդոյն' => 'խորհրդոյն',
	'Մատթէոս' => 'մատթէոս',
	'Ուռհայեցի' => 'ուռհայեցի',
	'զըգործ' => 'զգործ',
	'ժամանակագըրութեանց' => 'ժամանակագրութեանց',
	'սըրբոց' => 'սրբոց',
	'սըրբութեան' => 'սրբութեան',
	'սկըսաւ' => 'սկսաւ',
	'Յովհաննիսի' => 'յովհաննիսի',
	'Յովհաննիսէ' => 'յովհաննիսէ',
	'Հոռոմոց' => 'հոռոմոց',
	'զըայս' => 'զայս',
	'ըզդառնաշունչ' => 'զդառնաշունչ',
	'ընթերցաւղսն' => 'ընթերցողսն',
	'լսաւղացն' => 'լսողացն',
	'զըբանս' => 'զբանս',
	'զքակտումըն' => 'զքակտումն',
	'գըտեալ' => 'գտեալ',
	'ըզշարագրական' => 'զշարագրական',
	'գըտանել' => 'գտանել',
	'իբըրև' => 'իբրև',
	'գըրեցի' => 'գրեցի',
	'քընընութեանց' => 'քննութեանց',
	'Աստուած' => 'աստուած',
	'Տէր' => 'տէր',
	'զըմեզ' => 'զմեզ',
	'ըզխրատն' => 'զխրատն',
	'ըզխրատս' => 'զխրատս',
	'զհատուցումըն' => 'զհատուցումն',
	'Մատթէոսի' => 'մատթէոսի',
	'Ուռհայեցւոյ' => 'ուռհայեցւոյ',
	'Պաւղոսի' => 'պաւղոսի',
	'Անտիոքայ' => 'անտիոքայ',
	'Բարսղի' => 'բարսղի',
	'Գրիգորիսի' => 'գրիգորիսի',
	'Կոստանդնուպաւլիս' => 'կոստանդնուպաւլիս',
	'Նիկաւլայ' => 'նիկաւլայ',
	'Նիկոլայ' => 'նիկաւլայ',
	'Տեառն' => 'տեառն',
	'երկըրպագութեանս' => 'երկրպագութեանս',
	'Սիմէաւնի' => 'սիմէաւնի',
	'զըաստուածասաստ' => 'զաստուածասաստ',
	'խընդրել' => 'խնդրել',
	'հըմտութեամբ' => 'հմտութեամբ',
	'զխըրատն' => 'զխրատն',
	'Միջագետաց' => 'միջագետաց',
	'զըամս' => 'զամս',
	'Բելիարայ' => 'բելիարայ',
	'Յորդանան' => 'յորդանան',
	'Փրկիչն' => 'փրկիչն',
	'փըրկիչն' => 'փրկիչն',
	'մըթացաւ' => 'մթացաւ',
	'յՈւռհա' => 'յուռհա',
	'Քրիստոսի' => 'քրիստոսի',
	'տըկարանայ' => 'տկարանայ',
	'Աւետարանին' => 'աւետարանին',
	'գըտանին' => 'գտանին',
	'ըզպատուիրանն' => 'զպատուիրանն',
	'ըզդրունս' => 'զդրունս',
	'մըտանեն' => 'մտանեն',
	'բարէկամաց' => 'բարեկամաց',
	'գոյթ' => 'գութ',
	'ծնաւղքն' => 'ծնողքն',
	'տըկարանան' => 'տկարանան',
	'քընընութեամբ' => 'քննութեամբ',
	'քընընողաց' => 'քննողաց',
	'յոչընչէ' => 'յոչնչէ',
	'հընարով' => 'հնարով',
	'պընդագոյնս' => 'պնդագոյնս',
	'յոչընչոյ' => 'յոչնչոյ',
	'քըննութեամբ' => 'քննութեամբ',
	'զվըճարեալ' => 'զվճարեալ',
	'գըտանէաք' => 'գտանէաք',
	'շըրջեալ' => 'շրջեալ',
	'փափաքանաւք' => 'փափագանաւք',
	'զընա' => 'զնա',
	'գըրոցս' => 'գրոցս',
	'փռանկ' => 'ֆռանգ',
	'ֆռանդ' => 'ֆռանգ',
	'ֆռանկ' => 'ֆռանգ',
	'Ֆռանգ' => 'ֆռանգ',
	'Ֆռանկ' => 'ֆռանգ',
	'Փռանգ' => 'ֆռանգ',
	'Փռանկ' => 'ֆռանգ',
	'վռանգ' => 'ֆռանգ',
	'փռանգ' => 'ֆռանգ',
	'փռանկք' => 'ֆռանգք',
	'ֆռանդք' => 'ֆռանգք',
	'ֆռանկք' => 'ֆռանգք',
	'Ֆռանգք' => 'ֆռանգք',
	'Ֆռանկք' => 'ֆռանգք',
	'Փռանգք' => 'ֆռանգք',
	'Փռանկք' => 'ֆռանգք',
	'Հռոմայեցւոց' => 'հռոմայեցւոց',
	'Ալէքսին' => 'ալէքսին',
	'Յունաց' => 'յունաց',
	'մընացեալ' => 'մնացեալ',
	'յասպարիսի' => 'յասպարիզի',
	'հըռոմայեցւոց' => 'հռոմայեցւոց',
	'գըրեալ' => 'գրեալ',
	'աստեղքըն' => 'աստեղքն',
	'զըայն' => 'զայն',
	'Պաւղոս' => 'պաւղոս',
	'ըզդատաստանս' => 'զդատաստանս',
	'ըզհատուցումն' => 'զհատուցումն',
	'պոռընկութեամբ' => 'պոռնկութեամբ',
	'զըգողսն' => 'զգողսն',
	'յափըշտակեն' => 'յափշտակեն',
	'պոռընկասէրք' => 'պոռնկասէրք',
	'Խորհրդոյն' => 'խորհրդոյն',
	'Քրիստոս' => 'քրիստոս',
	'ճըշմարիտ' => 'ճշմարիտ',
	'պըղծեալս' => 'պղծեալս',
	'պըղծեալք' => 'պղծեալք',
	'ըզչորէքտասան' => 'զչորէքտասան',
	'Գրիգորի' => 'գրիգորի',
	'Կրաւնաւորք' => 'կրաւնաւորք',
	'զերգըս' => 'զերգս',
	'կըրաւնաւորքն' => 'կրաւնաւորքն',
	'կըրաւնաւորացն' => 'կրաւնաւորացն',
	'ճըգնաւորացն' => 'ճգնաւորացն',
	'գըլուխ' => 'գլուխ',
	'կըրաւնից' => 'կրաւնից',
	'յայսըմհետէ' => 'յայսմհետէ',
	'մըտեր' => 'մտեր',
	'Թուրքաց' => 'թուրքաց',
	'տաւնախըմբութիւնք' => 'տաւնախմբութիւնք',
	'Քամայ' => 'քամայ',
	'զըգենուն' => 'զգենուն',
	'ծըփի' => 'ծփի',
	'սըրով' => 'սրով',
	'Աստուածընկալ' => 'աստուածընկալ',
	'փըրկութենէն' => 'փրկութենէն',
	'ըսկիզբն' => 'սկիզբն',
	'գընդէն' => 'գնդէն',
	'գընտին' => 'գնտին',
	'ըզկնի' => 'զկնի',
	'Պարսիկք' => 'պարսիկք',
	'երուսաղէմ' => 'Երուսաղէմ',
	'զգընացս' => 'զգնացս',
	'ըզգնացս' => 'զգնացս',
	'ծընունդք' => 'ծնունդք',
	'ըզբազում' => 'զբազում',
	'զիշխանսըն' => 'զիշխանսն',
	'ըզհող' => 'զհող',
	'մըթերից' => 'մթերից',
	'այլազգեացըն' => 'այլազգեացն',
	'տունըն' => 'տունն',
	'գըրեցաք' => 'գրեցաք',
	'ըզլոյսն' => 'զլոյսն',
	'զըկամար' => 'զկամար',
	'ըզկամար' => 'զկամար',
	'ըզկարգ' => 'զկարգ',
	'ըզհրամանս' => 'զհրամանս',
	'յոչ' => 'ոչ',
	'ծնողքըն' => 'ծնողքն',
	'ծնընդոց' => 'ծննդոց',
	'կորըստեամբ' => 'կորստեամբ',
	'զամըս' => 'զամս',
	'կըրեն' => 'կրեն',
	'զփախուստըն' => 'զփախուստն',
	);

%SPELLINGS = (
	'ափշտակեն' => 'յափշտակեն',
	'արծաթասիրութեամբ' => 'արծաթսիրութեամբ',
	'ահայ որ' => 'ահա որ',
	'միջաւրէի' => 'մէջ աւրէի',
	'տիրերելով' => 'տիրելով',
	'տիէ' => 'տիրէ',
	'նորոքումն' => 'նորոգումն',
	'յանմարդս' => 'անմարդս',
	'յանմարդ' => 'անմարդ',
	'սուք' => 'սուգ',
	'և յանժամ' => 'և յայնժամ',
	'կորըսեամբ' => 'կորստեամբ',
	'յազգս ազգ' => 'յազգս ազգս',
	'արձակումք' => 'արձակմունք',
	'յարձակումք' => 'յարձակմունք',
	'այլազգաց' => 'այլազգեաց',
	'ահայ բեկեալ' => 'ահաբեկեալ',
	'զձեռնարդրութիւնն' => 'զձեռնադրութիւնն',
	'յահաբեկեալ' => 'ահաբեկեալ',
	'լայը' => 'լայր',
	'որդոյց' => 'որդւոց',
	'ծնաւղացն' => 'ծնողացն',
	'մայրքն' => 'մարքն',
	'աղեդեալ' => 'աղէտեալ',
	'աղետեալ' => 'աղէտեալ',
	'արմամբ' => 'այրմամբ',
	'հրհրով' => 'հրով',
	'յողարկեալն' => 'յուղարկեալն',
	'հհայրապետն' => 'հայրապետն',
	'յանժամ' => 'յայնժամ',
	'յոյ' => 'յոյս',
	'տկարանայցեն' => 'տկարանացեն',
	'առաշնորդացն' => 'առաջնորդացն',
	'ծնաւղաց' => 'ծնողաց',
	'ութսունից' => 'ութսնից',
	'չորեքհարիւրերրորդի' => 'չորեքհարիւրերորդի',
	'չորեքհարիւրերրորդի հինգհարիւրերրորդի' => 'չորեքհարիւրերորդի հինգհարիւրերորդի',
	'հինգհարիւրերրորդի' => 'հինգհարիւրերորդի',
	'յիսներրորդի' => 'յիսներորդի',
	'աղէքսանդու' => 'աղէքսանդրու',
	'յոհաննու' => 'յովհաննու',
	'յոհանու' => 'յովհաննու',
	'նեղութիւսըն' => 'նեղութիւնսն',
	'ասորոց' => 'ասորւոց',
	'մտայբերէ' => 'մտաբերէ',
	'զանկարաւղութիւն' => 'զանկարողութիւն',
	'թվականացն' => 'թուականացն',
	'յաթամայ' => 'յադամայ',
	'այսիրիկ' => 'այսորիկ',
	'ի վերա' => 'ի վերայ',
	'առցէն' => 'առցեն',
	'համաւրէն' => 'համարէն',
	'հարսանան' => 'հարստանան',
	'հարսընան' => 'հարստանան',
	'Յոհաննէս' => 'յովհաննէս',
	'իւրեան' => 'իւրեանց',
	'յղարկացեալ' => 'յուղարկեալ',
	'յղարկեաց' => 'յուղարկեաց',
	'յղըրկեաց' => 'յուղարկեաց',
	'յողարկեաց' => 'յուղարկեաց',
	'ներքո' => 'ներքոյ',
	'ոհաննէս' => 'յովհաննէս',
	'ուղարկեաց' => 'յուղարկեաց',
	'գետուն' => 'գետոյն',
	'գետո' => 'գետոյ',
	'զարծաթո' => 'զարծաթոյ',
	'զոսկո' => 'զոսկւոյ',
	'զոսկոյ' => 'զոսկւոյ',
	'մթէրից' => 'մթերից',
	'յանկոյս' => 'յայնկոյս',
	'ջահոյն' => 'ջահուն',
	'նորանա' => 'նորանայ',
	'աղբիւրք' => 'աղբերք',
	'աղբևրք' => 'աղբերք',
	'անտաստանք' => 'անդաստանք',
	'բխեսցեն' => 'բղխեսցեն',
	'յայնուհետև' => 'այնուհետև',
	'ջուրց' => 'ջրոց',
	'ջրւոց' => 'ջրոց',
	'յայժամ' => 'յայնժամ',
	'սկզբն' => 'սկիզբն',
	'ամ ամէ' => 'ամ յամէ',
	'յամ ամէ' => 'ամ յամէ',
	'յամ յամէ' => 'ամ յամէ',
	'Հռովմայեցւոց' => 'հռոմայեցւոց',
	'Հռովմէացւոց' => 'հռոմայեցւոց',
	'զարծւի' => 'զարծուի',
	'հոռոմայեցւոցն' => 'հռոմայեցւոցն',
	'հռաւմայէցւոց' => 'հռոմայեցւոց',
	'պարսիք' => 'պարսիկք',
	'տեղեպահ' => 'տեղապահ',
	'տեղէ պահ' => 'տեղապահ',
	'քննո' => 'քնոյ',
	'քնո' => 'քնոյ',
	'քնու' => 'քնոյ',
	'հոռոմէացւոց' => 'հռոմայեցւոց',
	'հռոմէացւոց' => 'հռոմայեցւոց',
	'յուսահին' => 'յուսահատին',
	'կրիցին' => 'կրեցին',
	'հաւատցեալք' => 'հաւատացեալք',
	'ահայ բեկին' => 'ահաբեկին',
	'յուսայ հատին' => 'յուսահատին',
	'ընդիր' => 'ընտիր',
	'ընդիրս' => 'ընտիրս',
	'ըտիր' => 'ընտիր',
	'բազումութեամբ' => 'բազմութեամբ',
	'էրուսաղէմ' => 'երուսաղէմ',
	'ծառաութենէ' => 'ծառայութենէ',
	'յէրուսաղէմ' => 'յերուսաղէմ',
	'աւիրելոց' => 'աւերելոց',
	'խաբանին' => 'խափանին',
	'գըռգըռին' => 'գրգռին',
	'գըռգռին' => 'գրգռին',
	'գռգռին' => 'գրգռին',
	'եղբայրք' => 'եղբարք',
	'եղբարութեանն' => 'եղբայրութեանն',
	'զերարս' => 'զիրեարս',
	'զիրարս' => 'զիրեարս',
	'հայրք' => 'հարք',
	'յեղբարք' => 'եղբարք',
	'սպաննութեամբ' => 'սպանութեամբ',
	'տաւնայ խնբութիւնք' => 'տաւնախմբութիւնք',
	'գործաւք' => 'գործովք',
	'եղբարութեան' => 'եղբայրութեան',
	'հաւասակից' => 'հաւասարակից',
	'անանաւրինաց' => 'անաւրինաց',
	'անդաստանանաց' => 'անդաստանաց',
	'անտաստանաց' => 'անդաստանաց',
	'զգենոյն' => 'զգենուն',
	'զըգենոյն' => 'զգենուն',
	'հիմացն' => 'հիմանց',
	'սովաւվ' => 'սովով',
	'տունախմբութիւնք' => 'տաւնախմբութիւնք',
	'զաւքն' => 'զաւրքն',
	'որդոցն' => 'որդւոցն',
	'սուրերի' => 'սուսերի',
	'քամա' => 'քամայ',
	'ազգս յազգս' => 'յազգս ազգս',
	'կգարգս' => 'կարգս',
	'յազգս այզգս' => 'յազգս ազգս',
	'պատերազմնել' => 'պատերազմել',
	'պատուիրաննաւն' => 'պատուիրանաւն',
	'պատուիրաւն' => 'պատուիրանաւն',
	'սատանա' => 'սատանայ',
	'վասն որո' => 'վասն որոյ',
	'խոցամբ' => 'խոցմամբ',
	'վիրաւորեալոց' => 'վիրաւորելոց',
	'էթէ' => 'եթէ',
	'վիճարելոց' => 'վճարելոց',
	'քահանայյական' => 'քահանայական',
	'աղթից' => 'ախտից',
	'աղագս' => 'յաղագս',
	'անգեալս' => 'անկեալս',
	'լինիցեն' => 'լինիցին',
	'խանկարիչք' => 'խանգարիչք',
	'խանքարիչք' => 'խանգարիչք',
	'յառաջնորդք' => 'առաջնորդք',
	'որդոյն' => 'որդւոյն',
	'փաղչին' => 'փախչին',
	'աղտից' => 'ախտից',
	'ցանգասէրք' => 'ցանկասէրք',
	'ցանկայ սէրք' => 'ցանկասէրք',
	'կրոնաւորք' => 'կրաւնաւորք',
	'յանապէն' => 'յանապատէն',
	'որոճան' => 'որոճեն',
	'որոջճալով' => 'որոճալով',
	'փախչեն' => 'փախչին',
	'փաղխչեն' => 'փախչին',
	'փաղչեն' => 'փախչին',
	'փաղչին' => 'փախչին',
	'փափագաւղք' => 'փափագողք',
	'փափագքողք' => 'փափագողք',
	'փափաք քողք' => 'փափագողք',
	'փափաքաւղք' => 'փափագողք',
	'փափաքողք' => 'փափագողք',
	'էն' => 'են',
	'լինելո' => 'լինելոյ',
	'կրանաւորաց' => 'կրաւնաւորաց',
	'կրոնաւորաց' => 'կրաւնաւորաց',
	'Մաթէոս' => 'մատթէոս',
	'ախղտին' => 'ախտին',
	'աղթին' => 'ախտին',
	'աղխտին' => 'ախտին',
	'յազգըս յազգս' => 'յազգս ազգս',
	'զառաքինսն' => 'զառաքինիսն',
	'զարնարատն' => 'զանարատն',
	'չունելո' => 'չունելոյ',
	'քահանայուենէ' => 'քահանայութենէ',
	'յազգս յազգս' => 'յազգս ազգս',
	'ափըշտակեն' => 'յափշտակեն',
	'զաշատողացն' => 'զաշխատողացն',
	'մեարեն' => 'մեծարեն',
	'ուղել' => 'ուղղել',
	'ուղեղ' => 'ուղիղ',
	'պաւռնկասէրք' => 'պոռնկասէրք',
	'պոռընկայ սէրք' => 'պոռնկասէրք',
	'Պաւռնկութեամբ' => 'պոռնկութեամբ',
	'ատեցաւղք' => 'ատեցողք',
	'պոռնակասէրք' => 'պոռնկասէրք',
	'աստեղղքն' => 'աստեղքն',
	'ահաւարի' => 'ահաւորի',
	'դատաստին' => 'դատաստանին',
	'մոռան' => 'մոռանան',
	'յիշանաց' => 'յիշխանաց',
	'ցանկացաւղք' => 'ցանկացողք',
	'փափականաւք' => 'փափագանաւք',
	'փափանաւք' => 'փափագանաւք',
	'մշտնչենաւորք' => 'մշտնջենաւորք',
	'կերիցէն' => 'կերիցեն',
	'նիւսսացոյն' => 'նիւսացւոյն',
	'հրաչարեալ' => 'հրաժարեալ',
	'պատմայգրութենէն' => 'պատմագրութենէն',
	'անսղալ' => 'անսխալ',
	'պտմեսցեն' => 'պատմեսցեն',
	'բարկանա' => 'բարկանայ',
	'զյիշխանութիւն' => 'զիշխանութիւն',
	'թիւրէն' => 'թիւրեն',
	'անարժութեամբ' => 'անարժանութեամբ',
	'արծաթասիրութեան' => 'արծաթսիրութեան',
	'բազւմ' => 'բազում',
	'խորհուրդոյն' => 'խորհրդոյն',
	'կարք' => 'կարգ',
	'հակառակուենէ' => 'հակառակութենէ',
	'հոգոյն' => 'հոգւոյն',
	'ուրէք' => 'ուրեք',
	'պատարագաւղ' => 'պատարագող',
	'կաշառոցն' => 'կաշառացն',
	'հովւել' => 'հովուել',
	'յաղաքս' => 'յաղագս',
	'պաւղաւս' => 'պաւղոս',
	'սուտերդումք' => 'սուտերդմունք',
	'խաւսայ կարգութիւնս' => 'խաւսակարգութիւնս',
	'խաւսայկարգութիւնս' => 'խաւսակարգութիւնս',
	'հոգեբարձութեամբ' => 'հոգաբարձութեամբ',
	'աւրինակաս' => 'աւրինակաւս',
	'երկրապագութեանց' => 'երկրպագութեանց',
	'զբազմանաց' => 'զբաղմանաց',
	'պայքարնումն' => 'պայքարումն',
	'սբաղանաց' => 'զբաղանաց',
	'հոգէբարձութեամբ' => 'հոգաբարձութեամբ',
	'հոգոգեբարձութեամբ' => 'հոգաբարձութեամբ',
	'մատենայ գրութիւնս' => 'մատենագրութիւնս',
	'սնայփառութեանց' => 'սնափառութեանց',
	'զանկարաւղութիւնս' => 'զանկարողութիւնս',
	'արհեստիւք' => 'արուեստիւք',
	'զսղալանս' => 'զսխալանս',
	'նոքայ' => 'նոքա',
	'նք' => 'նոքա',
	'սղալանս' => 'սխալանս',
	'տըւաւ' => 'տուաւ',
	'հռոմայեցոց' => 'հռոմայեցւոց',
	'հըռոմայեցոց' => 'հռոմայեցւոց',
	'հռոմայոց' => 'հռոմայեցւոց',
	'հռոմայեցւոյց' => 'հռոմայեցւոց',
	'հռոմաեցոց' => 'հռոմայեցւոց',
	'հոռոմաեցւոց' => 'հռոմայեցւոց',
	'հռովմայեցւոց' => 'հռոմայեցւոց',
	'հռոմայեցոց' => 'հռոմայեցւոց',
	'հոռոմացւոց' => 'հռոմայեցւոց',
	'հռոմաեցւոց' => 'հռոմայեցւոց',
	'հռոմաէցւոց' => 'հռոմայեցւոց',
	'հոռոմայեցոց' => 'հռոմայեցւոց',
	'հռաւմայեցւոց' => 'հռոմայեցւոց',
	'հռոմայեցոց' => 'հռոմայեցւոց',
	'հոռոմայեցւոց' => 'հռոմայեցւոց',
	'թվականութիւնս' => 'թուականութիւնս',
	'յաճեաց' => 'աճեաց',
	'յաճոեաց' => 'աճեաց',
	'ալեկործութեն' => 'ալեկոծութեանն',
	'նավակոծեցաւ' => 'նաւակոծեցաւ',
	'նաւակոզեցաւ' => 'նաւակոծեցաւ',
	'ոկիանոսի' => 'ովկիանոսի',
	'փութաւ' => 'փութով',
	'փութա' => 'փութայ',
	'կետ' => 'կէտ',
	'կամեցա' => 'կամեցայ',
	'համայտարած' => 'համատարած',
	'դեգրէաք' => 'դեգերէաք',
	'զթվականութիւնս' => 'զթուականութիւնս',
	'ընդերձեալ' => 'ընթերցեալ',
	'ընդերցեալ' => 'ընթերցեալ',
	'Արծւոյ' => 'արծուոյ',
	'առնեալ' => 'առնել',
	'թվականութեամբ' => 'թուականութեամբ',
	'հնկետասան' => 'հնգետասան',
	'միայհամուռն' => 'միահամուռն',
	'արծւոյ' => 'արծուոյ',
	'կարաւղութեամբ' => 'կարողութեամբ',
	'քաջաթռչիչքն' => 'քաջաթռիչքն',
	'երբայութեան' => 'երկբայութեան',
	'երկբաութեան' => 'երկբայութեան',
	'կարաւղ' => 'կարող',
	'արմութիւնս' => 'ամրութիւնս',
	'թռնչոց' => 'թռչնոց',
	'որդոց' => 'որդւոց',
	'պնդայ գոյնս' => 'պնդագոյնս',
	'պնտագոյնս' => 'պնդագոյնս',
	'յոչինչոյ' => 'յոչնչոյ',
	'շիւղաբեր' => 'շիղաբեր',
	'ոչինչո' => 'յոչնչոյ',
	'բարէկամաց' => 'բարեկամաց',
	'թուլամորթեն' => 'թուլամորթին',
	'հաւատու' => 'հաւատոյ',
	'դիմայ գրութիւնս' => 'դիմագրութիւնս',
	'զմատենագրուիս' => 'զմատենագրութիւնս',
	'զմատնագրութիւնս' => 'զմատենագրութիւնս',
	'ընդդիմանա' => 'ընդդիմանայ',
	'ընդէմ' => 'ընդդէմ',
	'ընդիմանամք' => 'ընդդիմանամք',
	'ընդիմանայ' => 'ընդդիմանայ',
	'խաւսեցայք' => 'խաւսեցաք',
	'խոսեցաք' => 'խաւսեցաք',
	'հեռետորաց' => 'հռետորաց',
	'հերձրուածք' => 'հերձուածք',
	'Յաղաքս' => 'Յաղագս',
	'թողոյն' => 'թողուն',
	'աւրհերգութիւնք' => 'աւրհներգութիւնք',
	'աւրհներգուիք' => 'աւրհներգութիւնք',
	'յաւհներգութիւնք' => 'յաւրհներգութիւնք',
	'գոյթ' => 'գութ',
	'ծնաւղքն' => 'ծնողքն',
	'զպտուիրանն' => 'զպատուիրանն',
	'առաջնոդացն' => 'առաջնորդացն',
	'ըն' => 'ընդ',
	'լուծովք' => 'լծով',
	'խրատոյ' => 'խրատու',
	'հաւանեն' => 'հաւանին',
	'հպահոցն' => 'պահոցն',
	'պատուիրանինացն' => 'պատուիրանացն',
	'անգոսեն' => 'անգոսնեն',
	'անկոսնեն' => 'անգոսնեն',
	'տկարանա' => 'տկարանայ',
	'տկարանացեն' => 'տկարանայցեն',
	'գինտականաց' => 'գիտնականաց',
	'մեղւացն' => 'մեղաւորացն',
	'բառնա' => 'բառնայ',
	'երկեղ' => 'երկիւղ',
	'հաւդերձելոցն' => 'հանդերձելոցն',
	'այնժամ' => 'յայնժամ',
	'մթեցաւ' => 'մթացաւ',
	'եկեղեցո' => 'եկեղեցւոյ',
	'եկեղեցոյ' => 'եկեղեցւոյ',
	'չրջելոց' => 'շրջելոց',
	'սւորբ' => 'սուրբ',
	'պահանճէ' => 'պահանջէ',
	'դասպետութիւնս' => 'դասապետութիւնս',
	'դասսպետութիւնս' => 'դասապետութիւնս',
	'զարմանք' => 'զարմանամք',
	'թէ' => 'եթէ',
	'յոչինչ' => 'ոչինչ',
	'նոցայ' => 'նոցա',
	'գա' => 'գայ',
	'իւրաւք' => 'իւրովք',
	'կենդանանա' => 'կենդանանայ',
	'կա' => 'կայ',
	'չաչարանաց' => 'չարչարանաց',
	'30ից' => '30նից',
	'արաբար' => 'արիաբար',
	'արիայբար' => 'արիաբար',
	'հըրամաեցաւ' => 'հրամայեցաւ',
	'արհեստ' => 'արուեստ',
	'թուղուլ' => 'թողուլ',
	'շառաւիղս' => 'շառաւեղս',
	'շաւեղս' => 'շաւիղս',
	'շաւուեղս' => 'շաւիղս',
	'սայ' => 'սա',
	'բացեա' => 'բացեայ',
	'զարեստ' => 'զարուեստ',
	'ապայ' => 'ապա',
	'ապայ գայիցն' => 'ապագայիցն',
	'բարկրւթիւնս' => 'բարկութիւնս',
	'գլաւրեալ' => 'գլորեալ',
	'յիշտակ' => 'յիշատակ',
	'երուսաղէմի' => 'երուսաղէմայ',
	'էրուսաղէմե' => 'երուսաղէմայ',
	'սիմէոնի' => 'սիմէաւնի',
	'Կոստանդինուպաւլիս' => 'կոստանդնուպաւլիս',
	'անդիոքա' => 'անտիոքայ',
	'բարսեղի' => 'բարսղի',
	'կոստանդինուպաւլիս' => 'կոստանդնուպաւլիս',
	'կոստանդնուպաւղիս' => 'կոստանդնուպաւլիս',
	'հայրապետութենն' => 'հայրապետութեանն',
	'հռոմոց' => 'հոռոմոց',
	'նիկաւլա' => 'նիկաւլայ',
	'500երրորդի' => '500երորդի',
	'50երրորդի' => '50երորդի',
	'առաշինն' => 'առաջինն',
	'արուստաւոր' => 'արուեստաւոր',
	'դատարեցաք' => 'դադարեցաք',
	'ելանալոյ' => 'ելանելոյ',
	'ելանալով' => 'ելանելով',
	'թողք' => 'թողաք',
	'հանճարեղինաց' => 'հանճարեղացն',
	'հարուստաւոր' => 'հարստաւոր',
	'յարուստաւոր' => 'յարուեստաւոր',
	'յարստաւոր' => 'հարստաւոր',
	'տեղոջ' => 'տեղւոջ',
	'իրիցու' => 'երիցու',
	'մաթէոսի' => 'մատթէոսի',
	'յուռհաեցո' => 'ուռհայեցւոյ',
	'յուռհայեցոյ' => 'ուռհայեցւոյ',
	'յուռհացոյ' => 'ուռհայեցւոյ',
	'ուռհաեցո' => 'ուռհայեցւոյ',
	'ուռհայեցոյ' => 'ուռհայեցւոյ',
	'ուռհացոյ' => 'ուռհայեցւոյ',
	'աւգտակարասցեն' => 'աւգտակարեսցեն',
	'աւգտակարեսցին' => 'աւգտակարեսցեն',
	'յիշեսցեսցեն' => 'յիշեսցեն',
	'կողմանծ' => 'կողմանց',
	'դգերեալ' => 'դեգերեալ',
	'մերո' => 'մերոյ',
	'մոռացանուցանել' => 'մոռացուցանել',
	'շիջիմք' => 'շրջիմք',
	'զկիսբն' => 'զսկիզբն',
	'յատենագրութիւն' => 'մատենագրութիւն',
	'մոռացցի' => 'մոռասցի',
	'դիւրեաւ' => 'դիւրաւ',
	'դիւրւ' => 'դիւրաւ',
	'զձգործ' => 'զգործ',
	'ժամանագրութեանց' => 'ժամանակագրութեանց',
	'ժամանկագրութեանց' => 'ժամանակագրութեանց',
	'համարեցա' => 'համարեցայ',
	'մաթէոս' => 'մատթէոս',
	'յուռհաեցի' => 'ուռհայեցի',
	'յուռհայեցի' => 'ուռհայեցի',
	'որժամ' => 'յորժամ',
	'ուռհաեցի' => 'ուռհայեցի',
	'ուռհացի' => 'ուռհայեցի',
	'ուրհայեցի' => 'ուռհայեցի',
	'վասն այսիրիկ' => 'վասն այսորիկ',
	'տեսուութիւն' => 'տեսութիւն',
	'ազագացս' => 'ազգացս',
	'վար' => 'վայր',
	'խորհոյս' => 'խորհրդոյս',
	'խորհրդուս' => 'խորհրդոյս',
	'ուզմամբ' => 'յուզմամբ',
	'զքակումն' => 'զքակտումն',
	'զքատկումն' => 'զքակտումն',
	'յաւհանիսէ' => 'յովհաննիսէ',
	'յոհանիսէ' => 'յովհաննիսէ',
	'յոհաննիսէ' => 'յովհաննիսէ',
	'վիաւոր' => 'վիրաւոր',
	'անկամ' => 'անգամ',
	'ասոցիկ' => 'այսոցիկ',
	'ելիմացւոց ազգէն' => 'եղիմնացւոց ազգէն',
	'եղբեղբարց' => 'եղբարց',
	'եղիմացւոց ազգէն' => 'եղիմնացւոց ազգէն',
	'եղիմնացոց ազգէն' => 'եղիմնացւոց ազգէն',
	'եղիմնացոց յազգէն' => 'եղիմնացւոց յազգէն',
	'թուրգաց' => 'թուրքաց',
	'ժամակաց' => 'ժամանակաց',
	'հետաքնեալ' => 'հետաքննեալ',
	'պատգամագրացն' => 'պատմագրացն',
	'պատգամագրոց' => 'պատմագրացն',
	'պատմայգրացն' => 'պատմագրացն',
	'վշտանգեալ' => 'վշտագնեալ',
	'վշտանկեալ' => 'վշտագնեալ',
	'վտանգեալ' => 'վշտագնեալ',
	'համարձեկեցան' => 'համարձակեցան',
	'սկաւ' => 'սկսաւ',
	'քահանականութեան' => 'քահանայականութեան',
	'վարցանել' => 'հարցանել',
	'նայ' => 'նա',
	'զարտասուն' => 'զարտասուսն',
	'զարտասունս' => 'զարտասուսն',
	'զկուծս' => 'զկուրծս',
	'արձակմնն' => 'արձակմանն',
	'բելիարա' => 'բելիարայ',
	'զնայ' => 'զնա',
	'սուգքս' => 'սուգս',
	'սուքս' => 'սուգս',
	'հարցանէլ' => 'հարցանել',
	'ցնայ' => 'ցնա',
	'բերանո' => 'բերանոյ',
	'հառաչանցն' => 'հառաչանացն',
	'գրիգիր' => 'գրիգոր',
	'կար' => 'կայր',
	'հակազան' => 'հայկազան',
	'մագիիստրոսն' => 'մագիստրոսն',
	'մագիրստրոսն' => 'մագիստրոսն',
	'մակիտտրոցն' => 'մագիստրոսն',
	'ումանք' => 'ոմանք',
	'վասակա' => 'վասակայ',
	'վարդավեետն' => 'վարդապետն',
	'քահանաիցն' => 'քահանայիցն',
	'ահայբեկեալ' => 'ահաբեկեալ',
	'հայց' => 'հայոց',
	'յաւհանիսի' => 'յովհաննիսի',
	'յոհանիսի' => 'յովհաննիսի',
	'յոհաննիսի' => 'յովհաննիսի',
	'յովանիսի' => 'յովհաննիսի',
	'յանժամ' => 'յայնժամ',
	'յաւհանէս' => 'յովհաննէս',
	'յաւհաննէս' => 'յովհաննէս',
	'յղարկեալ' => 'յուղարկեալ',
	'յոհանէս' => 'յովհաննէս',
	'յոհաննէս' => 'յովհաննէս',
	'յողարկեալ' => 'յուղարկեալ',
	'յովանէս' => 'յովհաննէս',
	'յովաննէս' => 'յովհաննէս',
	'յովհանէս' => 'յովհաննէս',
	'ուղարկեալ' => 'յուղարկեալ',
	'երկեղէն' => 'երկիւղէն',
	'իւրացն' => 'իրացն',
	'հիանաին' => 'հիանային',
	'յերկեղէն' => 'յերկիւղէն',
	'յերկիղէն' => 'յերկիւղէն',
	'իւեանց' => 'իւրեանց',
	'լաին' => 'լային',
	'երէրալով' => 'երերալով',
	'լերիննք' => 'լերինք',
	'գոջեաց' => 'գոչեաց',
	'սեաւացեալ' => 'սևացեալ',
	'թվականութեանս' => 'թուականութեանս',
	'թւականութեանս' => 'թուականութեանս',
	'տաւմարիս' => 'տոմարիս',
	'տումարիս' => 'տոմարիս',
	'կատարծի' => 'կատարածի',
	'Բարկանա' => 'Բարկանայ',
	'ահայ' => 'ահա',
	'աղտին' => 'ախտին',
	'այսմհետէ' => 'յայսմհետէ',
	'անտիոքա' => 'անտիոքայ',
	'արարածցս' => 'արարածոցս',
	'արութեանն' => 'արիութեանն',
	'դէգերեն' => 'դեգերին',
	'դէգերին' => 'դեգերին',
	'երկուշաբթին' => 'երկուշաբաթին',
	'զաւրմարտի' => 'զաւրամարտի',
	'զբնայբանն' => 'զբնաբանն',
	'զնայ' => 'զնա',
	'խաւատանէգն' => 'խաւատանէքն',
	'կաին' => 'կային',
	'հաոց' => 'հայոց',
	'հաւատո' => 'հաւատոյ',
	'հերա' => 'հերայ',
	'մայտանն' => 'մատանն',
	'մատուցանողին' => 'մատուցողին',
	'մատուցնողին' => 'մատուցողին',
	'յուռհայ' => 'յուռհա',
	'7ապատիկ' => '7պատիկ',
	'7նապատիկ' => '7պատիկ',
	'այսաւրիկ' => 'այսորիկ',
	'զսայ' => 'զսա',
	'նմայ' => 'նմա',
	'նորայ' => 'նորա',
	'շտապո' => 'շտապոյ',
	'պատագելոց' => 'պատարագելոց',
	'պաքարումն' => 'պայքարումն',
	'պեղծ' => 'պիղծ',
	'սիրո' => 'սիրոյ',
	'փաղչի' => 'փախչի',
	'քահայայիցն' => 'քահանայիցն',
	);

%PREFIXES = (
	'յա' => 'յա',
	'յադամայ' => 'յ|ադամայ',
	'յադամայէին' => 'յ|ադամայէին',
	'յազգէ' => 'յ|ազգէ',
	'յազգէն' => 'յ|ազգէն',
	'յազդումն' => 'յ|ազդումն',
	'յաթոռ' => 'յ|աթոռ',
	'յաթոռն' => 'յ|աթոռն',
	'յաթոռոյ' => 'յ|աթոռոյ',
	'յաթոռոյն' => 'յ|աթոռոյն',
	'յականատեսք' => 'յականատեսք',
	'յահաբեկեալ' => 'յ|ահաբեկեալ',
	'յահագին' => 'յ|ահագին',
	'յահաւոր' => 'յ|ահաւոր',
	'յաղաւթք' => 'յ|աղաւթք',
	'յաղէկսսանդրու' => 'յ|աղէկսսանդրու',
	'յաղէքսանդրիոյ' => 'յ|աղէքսանդրիոյ',
	'յաղջկունս' => 'յ|աղջկունս',
	'յամ' => 'յ|ամ',
	'յամառնային' => 'յ|ամառնային',
	'յամաւթով' => 'յ|ամաւթով',
	'յամենայն' => 'յ|ամենայն',
	'յամենայնի' => 'յ|ամենայնի',
	'յամէ' => 'յ|ամէ',
	'յամի' => 'յ|ամի',
	'յամին' => 'յ|ամին',
	'յամիս' => 'յ|ամիս',
	'յամիսս' => 'յ|ամիսս',
	'յամս' => 'յ|ամս',
	'յայժմ' => 'յայժմ',
	'յայլ' => 'յ|այլ',
	'յայլազգեացն' => 'յ|այլազգեացն',
	'յայլոց' => 'յ|այլոց',
	'յայն' => 'յ|այն',
	'յայնմ' => 'յ|այնմ',
	'յայնմիկ' => 'յ|այնմիկ',
	'յայնմիկ՝' => 'յ|այնմիկ՝',
	'յայնոսիկ' => 'յ|այնոսիկ',
	'յայնոսիկ՝' => 'յ|այնոսիկ՝',
	'յայնցեալ' => 'յ|այնցեալ',
	'յայսկոյս' => 'յ|այսկոյս',
	'յայսմ' => 'յ|այսմ',
	'յայսմիկ' => 'յ|այսմիկ',
	'յայսոսիկ' => 'յ|այսոսիկ',
	'յայսոցիկ' => 'յ|այսոցիկ',
	'յայսու' => 'յ|այսու',
	'յայրմանէ' => 'յ|այրմանէ',
	'յանապատ' => 'յ|անապատ',
	'յանաւրէն' => 'յ|անաւրէն',
	'յանաւրինաց' => 'յ|անաւրինաց',
	'յանդադար' => 'յ|անդադար',
	'յանդաստանացն' => 'յ|անդաստանացն',
	'յանդիոք' => 'յ|անդիոք',
	'յանդունդն' => 'յ|անդունդն',
	'յանդունդս' => 'յ|անդունդս',
	'յանեցի' => 'յ|անեցի',
	'յանկասկած' => 'յ|անկասկած',
	'յանկարծակի' => 'յանկարծակի',
	'յանհաւանութիւնս' => 'յ|անհաւանութիւնս',
	'յանձ' => 'յ|անձ',
	'յանձիթ' => 'յանձիթ',
	'յանձին' => 'յ|անձին',
	'յանձինս' => 'յ|անձինս',
	'յանձն' => 'յ|անձն',
	'յանմիկ' => 'յ|անմիկ',
	'յանունն' => 'յ|անունն',
	'յանպարիսբ' => 'յ|անպարիսբ',
	'յանջանս' => 'յ|անջանս',
	'յանտէր' => 'յ|անտէր',
	'յանտիոք' => 'յ|անտիոք',
	'յանտիոքա' => 'յ|անտիոքա',
	'յանտիոքայ' => 'յ|անտիոքայ',
	'յանտիոքացւոց' => 'յ|անտիոքացւոց',
	'յանտիրութենէ' => 'յ|անտիրութենէ',
	'յանտիրութենէն' => 'յ|անտիրութենէն',
	'յաշխարհ' => 'յ|աշխարհ',
	'յաշխարհաց' => 'յ|աշխարհաց',
	'յաշխարհին' => 'յ|աշխարհին',
	'յաշխարհն' => 'յ|աշխարհն',
	'յապագայից' => 'յ|ապագայից',
	'յապագայիցն' => 'յ|ապագայիցն',
	'յապականել' => 'յ|ապականել',
	'յաջոյ' => 'յ|աջոյ',
	'յառաջինն' => 'յ|առաջինն',
	'յառաւաւտն' => 'յ|առաւաւտն',
	'յասորոց' => 'յ|ասորոց',
	'յասորւոց' => 'յ|ասորւոց',
	'յասպարիզի՝' => 'յ|ասպարիզի՝',
	'յասպարիսի' => 'յ|ասպարիսի',
	'յաստեացս' => 'յ|աստեացս',
	'յաստուծոյ' => 'յ|աստուծոյ',
	'յատենագրութիւն' => 'յ|ատենագրութիւն',
	'յատենի' => 'յ|ատենի',
	'յատնեա՛ց' => 'յ|ատնեա՛ց',
	'յարարեալ' => 'յ|արարեալ',
	'յարդար' => 'յ|արդար',
	'յարդարադատէն' => 'յ|արդարադատէն',
	'յարեամբ' => 'յ|արեամբ',
	'յարեանարբու' => 'յ|արեանարբու',
	'յարեւելից' => 'յ|արեւելից',
	'յարեւելս' => 'յ|արեւելս',
	'յարեւմուտ' => 'յ|արեւմուտ',
	'յարեւմուտս' => 'յ|արեւմուտս',
	'յարեւմուտք' => 'յ|արեւմուտք',
	'յարեւմուտքն' => 'յ|արեւմուտքն',
	'յարեւմտից' => 'յ|արեւմտից',
	'յարիութեանն' => 'յ|արիութեանն',
	'յարիւն' => 'յ|արիւն',
	'յարիւնն' => 'յ|արիւնն',
	'յարկնի' => 'յ|արկնի',
	'յարուեստաւոր' => 'յ|արուեստաւոր',
	'յարտայայտէ' => 'յ|արտայայտէ',
	'յարքայութեանն' => 'յ|արքայութեանն',
	'յաւելորդ' => 'յ|աւելորդ',
	'յաւետարանէ' => 'յ|աւետարանէ',
	'յաւետարանէն' => 'յ|աւետարանէն',
	'յաւետարանն' => 'յ|աւետարանն',
	'յաւետարէ՛' => 'յ|աւետարէ՛',
	'յաւերումն' => 'յ|աւերումն',
	'յաւուր' => 'յ|աւուր',
	'յաւուրս' => 'յ|աւուրս',
	'յաւուրսն' => 'յ|աւուրսն',
	'յաւուրց' => 'յ|աւուրց',
	'յաւր' => 'յ|աւր',
	'յաւրն' => 'յ|աւրն',
	'յաքսորանս' => 'յ|աքսորանս',
	'յաքսորս' => 'յ|աքսորս',
	'յաքսորք' => 'յ|աքսորք',
	'յեզեր' => 'յ|եզեր',
	'յեզր' => 'յ|եզր',
	'յեկեղեցականաւք' => 'յ|եկեղեցականաւք',
	'յեկեղեցականքն' => 'յ|եկեղեցականքն',
	'յեկեղեցեացն' => 'յ|եկեղեցեացն',
	'յեկեղեցի' => 'յ|եկեղեցի',
	'յեկեղեցին' => 'յ|եկեղեցին',
	'յեկեղեցիք' => 'յ|եկեղեցիք',
	'յեկեղեցւոյ' => 'յ|եկեղեցւոյ',
	'յեկղցւոյն' => 'յ|եկղցւոյն',
	'յեկնից' => 'յ|եկնից',
	'յեղբայր' => 'յ|եղբայր',
	'յեղբարսն' => 'յ|եղբարսն',
	'յեղբարց' => 'յ|եղբարց',
	'յեղբաւրէ' => 'յ|եղբաւրէ',
	'յերեսաց' => 'յ|երեսաց',
	'յերեսս' => 'յ|երեսս',
	'յերից' => 'յ|երից',
	'յերկինս' => 'յ|երկինս',
	'յերկիր' => 'յ|երկիր',
	'յերկիրն' => 'յ|երկիրն',
	'յերկնային' => 'յ|երկնային',
	'յերկնից' => 'յ|երկնից',
	'յերկոցունց' => 'յ|երկոցունց',
	'յերկրի' => 'յ|երկրի',
	'յերկրին' => 'յ|երկրին',
	'յերուսաղէմայ' => 'յ|երուսաղէմայ',
	'յիմ' => 'յ|իմ',
	'յիմաստագրութիւն' => 'յ|իմաստագրութիւն',
	'յիմաստագրութիւնն' => 'յ|իմաստագրութիւնն',
	'յիմացեալ' => 'յ|իմացեալ',
	'յինէն' => 'յ|ինէն',
	'յիշխան' => 'յ|իշխան',
	'յիշխանաց' => 'յ|իշխանաց',
	'յիշխանութիւնս' => 'յ|իշխանութիւնս',
	'յիւր' => 'յ|իւր',
	'յիւրաքանչիւրում' => 'յ|իւրաքանչիւրում',
	'յիւրեանց' => 'յ|իւրեանց',
	'յիւրոց' => 'յ|իւրոց',
	'յշտապոյ' => 'յ|շտապոյ',
	'յո՜չնչէ' => 'յ|ո՜չնչէ',
	'յոչ' => 'յ|ոչ',
	'յոչինչ' => 'յ|ոչինչ',
	'յոչինչոյ' => 'յ|ոչինչոյ',
	'յոչնչէ' => 'յ|ոչնչէ',
	'յոչնչոյ' => 'յ|ոչնչոյ',
	'յոսկո' => 'յ|ոսկո',
	'յոսկոյ' => 'յ|ոսկոյ',
	'յոսկւոյ' => 'յ|ոսկւոյ',
	'յովկիանոս' => 'յ|ովկիանոս',
	'յովկիանոսի' => 'յ|ովկիանոսի',
	'յորդի' => 'յ|որդի',
	'յորդին' => 'յ|որդին',
	'յորդո' => 'յ|որդո',
	'յորդոյ' => 'յ|որդոյ',
	'յորդւոյ' => 'յ|որդւոյ',
	'յորում' => 'յ|որում',
	'յուզմամբ' => 'յուզմամբ',
	'յուժին' => 'յ|ուժին',
	'յունայ' => 'յունայ',
	'յունաց' => 'յունաց',
	'յունէր' => 'յունէր',
	'յուռհա' => 'յ|ուռհա',
	'յուռհայ' => 'յ|ուռհայ',
	'յուռհայեցի' => 'յ|ուռհայեցի',
	'յուռհայեցոյ' => 'յ|ուռհայեցոյ',
	'յուռհայոյ' => 'յ|ուռհայոյ',
	'յուռհայու' => 'յ|ուռհայու',
	'յուռհացոյ' => 'յ|ուռհացոյ',
	'յուրախութիւն' => 'յ|ուրախութիւն',
	'յսյսկոյս' => 'յ|սյսկոյս',
	);

%SUFFIXES = ();

1;

=head1 AUTHOR

Tara L Andrews E<lt>aurum@cpan.orgE<gt>
