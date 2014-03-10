function getHTML () {
	// Take the contents of the form, return an HTML snippet, pop up the 
	// dialog window that displays the HTML and offers XML download.
	var formvals = $('#transcriptionform').serialize();
	$.post( baseurl + 'convert_transcription', formvals, function( data ) {
		// Returned keys are textcontent, textdescription, textsigil
		$('#witsigil').empty().append( data['textsigil'] );
		$('#witid').empty().append( data['textidentifier'] );
		$('#textdescription').empty().append( data['textdescription'] );
		$('#sourcetext').empty().append( data['textcontent'] );
		$('#witness_container').dialog('open');
	});
}

$(document).ready(function() {
	// Make an accordion of the UI.
	$('#transcription_input').accordion();
	// Make a pretty button for the form.
	$('#do_convert').button().click( function (e) { 
		getHTML(); 
		e.preventDefault(); 
	});
	// Set up the results display.
	$('#witness_container').dialog({
        autoOpen: false,
        height: 800,
        width: 900,
        modal: true,
        buttons: {
        	"Download XML": function (evt) {
				window.location = baseurl + 'session_xml';
        	},
        	"Close": function () {
        		$( this ).dialog( 'close' );
        	}
		}
	});
});
