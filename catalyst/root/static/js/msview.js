function getHTML () {
	// Take the contents of the form, return an HTML snippet, pop up the 
	// dialog window that displays the HTML and offers XML download.
	$('.error').empty();
	var formvals = $('#transcriptionform').serialize();
	$.post( baseurl + 'convert_transcription', formvals, function( data ) {
		// Returned keys are textcontent, textdescription, textsigil, textidentifier,
		//   warnings, error_msg
		if( data['error_msg'] ) {
			// Display the error box
			$('.error').append( data['error_msg'] );
		} else {
			$('#witsigil').empty().append( data['textsigil'] );
			$('#witid').empty().append( data['textidentifier'] );
			$('#textdescription').empty().append( data['textdescription'] );
			makeProblemReport( data['warnings'] );
			$('#sourcetext').empty().append( data['textcontent'] );
			$('#witness_container').dialog('open');
		}
	});
}

function makeProblemReport( problems ) {
	$('#problemreport').empty();
	$.each( problems, function( idx, data ) {
		// Make a short formatted problem description of the data.
		$('<span>').attr('class', 'problem').append( data ).appendTo('#problemreport');
	});
}

function clearData () {
	// Send a message to the server to clear the contents of the session,
	// and re-retrieve the default XML template.
	$.post( baseurl + 'reset_all', function( data ) {
		$('#markuptext').val('');
		$('#transcriptionform input[name="language"]').prop('checked', false);
		$('#xmltemplate').val( data['xmltemplate'] );
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
	$('#clear_form').button().click( function (e) { 
		clearData(); 
		e.preventDefault(); 
	});
	// Set up the results display.
	$('#witness_container').dialog({
        autoOpen: false,
        height: 800,
        width: 900,
        modal: true,
        buttons: {
        	"Download XML": function () {
				window.location = baseurl + 'session_xml';
        	},
        	"Download JSON": function () {
        		window.location = baseurl + 'session_json';
        	},
        	"Close": function () {
        		$( this ).dialog( 'close' );
        	}
		}
	});
});
