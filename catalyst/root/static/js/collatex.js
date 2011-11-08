
// Set the name and language of the text, and display column 2 (file upload).
function stepOne() {
    var data = {};
    data.name = $('#textName').val();
    data.language = $('input:radio[name=lang]:checked').val();
    $.getJSON('collate/setNameLang', data, 
    function(response) {
        // unhide section two
        if( response.status == "ok" ) {
            $('#column2').unblock();
            $('#column2').removeClass( 'greyed_out' );
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
            $('#column3').unblock();
            $('#column3').removeClass('greyed_out');
          }
        });
    } else {
        showErrorConsole( 'Please make sure that each text you wish to collate has a unique sigil.  You may edit the sigla in the list.')
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
    meta_text: 'Give the name and language of the text you will collate.  The language setting is used to optimize collation results; the name will be added to certain results such as TEI output.',
    select_files: 'Use the "Add files" button to choose the files that contain your text; when you have selected the files, press the "Start upload" button.  These may be in plaintext format or in TEI XML format.  See the instructions for more information on TEI formatting guidelines.',
    select_texts: 'You should ensure here that the sigil you wish to use for each text is correct.  You may also exclude texts from collation by unchecking them.'
    };

function showHelp( help_subject ) {
    $('#dialog').empty().append( "<p>" + help_items[help_subject] + "</p>" );
    $('#dialog').dialog( 'open' );
    $('#dialog').delay(15000).fadeOut(1000);
}

function clearForms() {
    $('form').each(function(index) {
        $(this).clearForm();
    });
    $('#fileupload').find('.cancel').click();
    $('#column2').addClass( 'greyed_out' );
    $('#column2').block({message:null});
    $('#column3').addClass( 'greyed_out' );
    $('#column3').block({message:null});
}

$(document).ready(function(e) {
    $.blockUI.defaults.overlayCSS = {};
    $('#collatedResult').val('');
    $("#error_console").ajaxError(function(event, request, settings){
        showErrorConsole( request.responseText );
    });
    $('#column3').addClass( 'greyed_out' );
    $('#column3').block({message:null});
});

$.fn.clearForm = function() {
  return this.each(function() {
    var type = this.type, tag = this.tagName.toLowerCase();
    if (tag == 'form')
      return $(':input',this).clearForm();
    if (type == 'text' || type == 'password' || tag == 'textarea')
      this.value = '';
    else if (type == 'checkbox' || type == 'radio')
      this.checked = false;
    else if (tag == 'select')
      this.selectedIndex = -1;
  });
};



