package Words::Armenian;

use strict;
use Exporter 'import';
use utf8;
use vars qw( %SPELLINGS %PREFIXES %SUFFIXES @EXPORT_OK );

@EXPORT_OK = qw( am_downcase );

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

sub canonize_word {
    my $word  = shift;

    # We don't really distinguish between commas and semicolons properly
    # in the manuscript.  Make them the same.
    $word =~ s/\./\,/g;

    # Get rid of accent marks.
    $word =~ s/՛//g;

    # Expand ligatures.
    $word =~ s/օ/աւ/g;
    $word =~ s/և/եւ/g;

    # Downcase the word.
    $word = am_downcase( $word );

    # Check our spelling hash.
    if( exists $SPELLINGS{$word} ) {
        $word = $SPELLINGS{$word};
    }

    return $word;
}

%SPELLINGS = (
    'զբնայբանն' => 'զբնաբանն',
    'հաւատո' => 'հաւատոյ',
    'զարս' => 'զաւրս',
    'շտապո' => 'շտապոյ',
    'այլազգացն' => 'այլազգեացն',
    'երկուշաբթին' => 'երկուշաբաթին',
    'խաւատանէգն' => 'խաւատանէքն',
    'փաղչի' => 'փախչի',
    'մայտանն' => 'մատանն',
    'արութեանն' => 'արիութեանն',
    'հաոց' => 'հայոց',
    'խաւատանեքն' => 'խաւատանէքն',
    'տեղաց' => 'տեղեաց',
    'ահայ' => 'ահա',
    'զաւրմարտի' => 'զաւրամարտի',
    'կողմանծ' => 'կողմանց',
    'յուռհայ' => 'յուռհա',
    'նորայ' => 'նորա',
    'կաին' => 'կային',
    'նմայ' => 'նմա',
    'հոռոմայտանն' => 'հոռոմատանն',
    'պաքարումն' => 'պայքարումն',
    'զմանգութիւն' => 'զմանկութիւն',
    'ուրհայ' => 'ուռհայ',
    'անտիոքա' => 'անտիոքայ',
    'հերա' => 'հերայ',
    );

%PREFIXES = (
    'յա' => 'յա',
    'յագդումն' => 'յագդումն',
    'յագին' => 'յագին',
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
    'յաղագս' => 'յաղագս',
    'յաղաւթս' => 'յաղաւթս',
    'յաղաւթք' => 'յ|աղաւթք',
    'յաղաքս' => 'յաղաքս',
    'յաղէկսսանդրու' => 'յ|աղէկսսանդրու',
    'յաղէքսանդրիոյ' => 'յ|աղէքսանդրիոյ',
    'յաղթանդամ' => 'յաղթանդամ',
    'յաղթեցին' => 'յաղթեցին',
    'յաղթութեամբ' => 'յաղթութեամբ',
    'յաղթութիւն' => 'յաղթութիւն',
    'յաղթութիւնն' => 'յաղթութիւնն',
    'յաղթութիւնս' => 'յաղթութիւնս',
    'յաղջկունս' => 'յ|աղջկունս',
    'յաճեաց' => 'յաճեաց',
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
    'յայնժամ' => 'յայնժամ',
    'յայնմ' => 'յ|այնմ',
    'յայնմիկ' => 'յ|այնմիկ',
    'յայնմիկ՝' => 'յ|այնմիկ՝',
    'յայնոսիկ' => 'յ|այնոսիկ',
    'յայնոսիկ՝' => 'յ|այնոսիկ՝',
    'յայնուհետեւ' => 'յայնուհետեւ',
    'յայնցեալ' => 'յ|այնցեալ',
    'յայսկոյս' => 'յ|այսկոյս',
    'յայսմ' => 'յ|այսմ',
    'յայսմիկ' => 'յ|այսմիկ',
    'յայսոսիկ' => 'յ|այսոսիկ',
    'յայսոցիկ' => 'յ|այսոցիկ',
    'յայսու' => 'յ|այսու',
    'յայտ' => 'յայտ',
    'յայտնեալ' => 'յայտնեալ',
    'յայտնեաց' => 'յայտնեաց',
    'յայրդ' => 'յայրդ',
    'յայրմանէ' => 'յ|այրմանէ',
    'յան' => 'յան',
    'յանապատ' => 'յ|անապատ',
    'յանաւրէն' => 'յ|անաւրէն',
    'յանաւրինաց' => 'յ|անաւրինաց',
    'յանդադար' => 'յ|անդադար',
    'յանդաստանացն' => 'յ|անդաստանացն',
    'յանդիոք' => 'յ|անդիոք',
    'յանդունդն' => 'յ|անդունդն',
    'յանդունդս' => 'յ|անդունդս',
    'յանեցի' => 'յ|անեցի',
    'յանժամ' => 'յանժամ',
    'յանկասկած' => 'յ|անկասկած',
    'յանկարծակի' => 'յանկարծակի',
    'յանհաւանութիւնս' => 'յ|անհաւանութիւնս',
    'յանձ' => 'յ|անձ',
    'յանձիթ' => 'յանձիթ',
    'յանձին' => 'յ|անձին',
    'յանձինս' => 'յ|անձինս',
    'յանձն' => 'յ|անձն',
    'յանմիկ' => 'յ|անմիկ',
    'յանուանէին' => 'յանուանէին',
    'յանուանին' => 'յանուանին',
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
    'յանցանաց' => 'յանցանաց',
    'յանցանացն' => 'յանցանացն',
    'յանցանացս' => 'յանցանացս',
    'յանցանաւք' => 'յանցանաւք',
    'յանցանել' => 'յանցանել',
    'յանցանոցն' => 'յանցանոցն',
    'յանցանք' => 'յանցանք',
    'յանցեալ' => 'յանցեալ',
    'յաշխարհ' => 'յ|աշխարհ',
    'յաշխարհաց' => 'յ|աշխարհաց',
    'յաշխարհին' => 'յ|աշխարհին',
    'յաշխարհն' => 'յ|աշխարհն',
    'յապա' => 'յապա',
    'յապագայից' => 'յ|ապագայից',
    'յապագայիցն' => 'յ|ապագայիցն',
    'յապականել' => 'յ|ապականել',
    'յապայ' => 'յապայ',
    'յաջոյ' => 'յ|աջոյ',
    'յառաջ' => 'յառաջ',
    'յառաջագոյն' => 'յառաջագոյն',
    'յառաջի' => 'յառաջի',
    'յառաջին' => 'յառաջին',
    'յառաջինն' => 'յ|առաջինն',
    'յառաջն' => 'յառաջն',
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
    'յարդ' => 'յարդ',
    'յարդար' => 'յ|արդար',
    'յարդարադատէն' => 'յ|արդարադատէն',
    'յարեամբ' => 'յ|արեամբ',
    'յարեան' => 'յարեան',
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
    'յարկաց' => 'յարկաց',
    'յարկնի' => 'յ|արկնի',
    'յարձակեալ' => 'յարձակեալ',
    'յարձակեցան' => 'յարձակեցան',
    'յարձակեցին' => 'յարձակեցին',
    'յարուեստաւոր' => 'յ|արուեստաւոր',
    'յարուց' => 'յարուց',
    'յարուցանեալ' => 'յարուցանեալ',
    'յարուցանել' => 'յարուցանել',
    'յարուցանէր' => 'յարուցանէր',
    'յարուցեալ' => 'յարուցեալ',
    'յարտայայտէ' => 'յ|արտայայտէ',
    'յարքայութեանն' => 'յ|արքայութեանն',
    'յաւգնութիւն' => 'յաւգնութիւն',
    'յաւելաւ' => 'յաւելաւ',
    'յաւելորդ' => 'յ|աւելորդ',
    'յաւետարանէ' => 'յ|աւետարանէ',
    'յաւետարանէն' => 'յ|աւետարանէն',
    'յաւետարանն' => 'յ|աւետարանն',
    'յաւետարէ՛' => 'յ|աւետարէ՛',
    'յաւերումն' => 'յ|աւերումն',
    'յաւժարական' => 'յաւժարական',
    'յաւժարեցայ' => 'յաւժարեցայ',
    'յաւժարեցի' => 'յաւժարեցի',
    'յաւժարութեամբ' => 'յաւժարութեամբ',
    'յաւժարութեան' => 'յաւժարութեան',
    'յաւժարութեանց' => 'յաւժարութեանց',
    'յաւուր' => 'յ|աւուր',
    'յաւուրս' => 'յ|աւուրս',
    'յաւուրսն' => 'յ|աւուրսն',
    'յաւուրց' => 'յ|աւուրց',
    'յաւր' => 'յ|աւր',
    'յաւրն' => 'յ|աւրն',
    'յափիշտակութիւն' => 'յափիշտակութիւն',
    'յափշտակեալ' => 'յափշտակեալ',
    'յափշտակութիւն' => 'յափշտակութիւն',
    'յաքսորանս' => 'յ|աքսորանս',
    'յաքսորս' => 'յ|աքսորս',
    'յաքսորք' => 'յ|աքսորք',
    'յեզեր' => 'յ|եզեր',
    'յեզր' => 'յ|եզր',
    'յել' => 'յել',
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
    'յեղեւ' => 'յեղեւ',
    'յետ' => 'յետ',
    'յետին' => 'յետին',
    'յետինս' => 'յետինս',
    'յերեսաց' => 'յ|երեսաց',
    'յերեսս' => 'յ|երեսս',
    'յերեւ' => 'յերեւ',
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
    'յիշատակ' => 'յիշատակ',
    'յիշատակարան' => 'յիշատակարան',
    'յիշատակարանս' => 'յիշատակարանս',
    'յիշատակել' => 'յիշատակել',
    'յիշատակս' => 'յիշատակս',
    'յիշել' => 'յիշել',
    'յիշեսցեն' => 'յիշեսցեն',
    'յիշեսցէ' => 'յիշեսցէ',
    'յիշեցից' => 'յիշեցից',
    'յիշխան' => 'յ|իշխան',
    'յիշխանաց' => 'յ|իշխանաց',
    'յիշխանութիւնս' => 'յ|իշխանութիւնս',
    'յիսնակաց' => 'յիսնակաց',
    'յիսնակին' => 'յիսնակին',
    'յիսնակին՝' => 'յիսնակին՝',
    'յիսներորդի' => 'յիսներորդի',
    'յիսնից' => 'յիսնից',
    'յիստակ' => 'յիստակ',
    'յիւր' => 'յ|իւր',
    'յիւրաքանչիւրում' => 'յ|իւրաքանչիւրում',
    'յիւրեանց' => 'յ|իւրեանց',
    'յիւրոց' => 'յ|իւրոց',
    'յշտապոյ' => 'յ|շտապոյ',
    'յո՜չնչէ' => 'յ|ո՜չնչէ',
    'յոժ' => 'յոժ',
    'յոհաննու' => 'յոհաննու',
    'յոհանու' => 'յոհանու',
    'յոյժ' => 'յոյժ',
    'յոյժգին' => 'յոյժգին',
    'յոյնս' => 'յոյնս',
    'յոյնսն' => 'յոյնսն',
    'յոյնք' => 'յոյնք',
    'յոյս' => 'յոյս',
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
    'յովհաննու' => 'յովհաննու',
    'յոր' => 'յոր',
    'յորդի' => 'յ|որդի',
    'յորդին' => 'յ|որդին',
    'յորդո' => 'յ|որդո',
    'յորդոյ' => 'յ|որդոյ',
    'յորդորել' => 'յորդորել',
    'յորդորելոյ' => 'յորդորելոյ',
    'յորդւոյ' => 'յ|որդւոյ',
    'յորժամ' => 'յորժամ',
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
    'յուսն' => 'յուսն',
    'յուսոց' => 'յուսոց',
    'յուսոցն' => 'յուսոցն',
    'յուրախութիւն' => 'յ|ուրախութիւն',
    'յսյսկոյս' => 'յ|սյսկոյս',
    'յստակ' => 'յստակ',
    );

%SUFFIXES = ();

1;
