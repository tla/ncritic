
// Set the name and language of the text, and display column 2 (file upload).
function stepOne() {
    var data = {};
    data.name = $('#textName').val();
    data.language = $('input:radio[name=lang]:checked').val();
    $.getJSON('collate/setNameLang', data, 
    function(response) {
        // unhide section two
        if( response.status == "ok" ) {
            $('#column2').show();
        }
    });
}



function getFileTexts() {
    $.getJSON('collate/return_texts', function(data) {
        $('#submittedFileList').html('');
        if (data) {
            $('#submitted_div').show();
        }
        $.each(data,
	function(index, properties) {
            text_id = properties.text;
            auto_sigil = properties.autosigil;
            text_form_item = '<li><input type="checkbox" checked="true" name="text" value="' + text_id + '"></input><input type="text" class="textfieldX sigil" name="sigil_' + text_id + '" id="sigil_' + text_id + '" value="' + auto_sigil + '"/><span class="text_name">' + properties.title + '</span></li>';
            $('#submittedFileList').append(text_form_item);
        });
    });
}

function validateSigla() {
    seenValues = [];
    valid = true;
    $.each( $('.sigil'), function( key, value ) {
        sigilValue = $(this).val();
        if( $.inArray( sigilValue, seenValues ) > -1 ){
            valid = false;
        } else {
            seenValues.push( sigilValue )
        }
    } );
    return valid;
}

function getTokens() {
    $('#collatedResult').val('');
    $('#ajax-loader').css('visibility', 'visible');
    if( validateSigla()==true ) {
        query = $('#Configureform').serialize();
        $.ajax({
          url: 'collate/collate_sources',
          data: query,
          type: 'POST',
          async: false,
          dataType: 'json',
          success: function(resp){
            $('#column3').show();
          }
        });
    } else {
        showErrorConsole( 'The sigla provide are not unique. Please correct and try again.')
    }
    $('#ajax-loader').css( 'visibility', 'hidden' );
}

function getResult(type) {
    formid = '#' + type + 'form';  // either Download or Display
    $(formid).submit();
}

function sendResult() {

}

function showErrorConsole( error_text ) {
    error_console = $("#error_console");
    error_console.empty(); 
    error_console.show();
    error_console.append('<div class="ajax_error">Uhoh, the service returned an error&hellip;<br/> ' + error_text + '</div>');
    error_console.delay(8000).fadeOut(1000);
}

var help_items = {
    text_name: 'Set here the name (title) of the text you are going to collate.',
    text_language: 'Set the language of the text.  This is used to optimize collation results.',
    select_files: 'Use the "Add files" button to choose the files that contain your text; when you have selected the files, press the "Start upload" button.  These may be in plaintext format or in TEI XML format.  See the instructions for more information on TEI formatting guidelines.'
    };

function showHelp( help_subject ) {
    $('#dialog').empty().append( "<p>" + help_items[help_subject] + "</p>" );
    $('#dialog').dialog( 'open' );
}
                    
$(document).ready(function(e) {
    $('#collatedResult').val('');
    $("#error_console").ajaxError(function(event, request, settings){
        showErrorConsole( request.responseText );
    });
    $('#column3').hide();
});

