function sendName() {
    var data = {};
    data.name = $('#textName').val();
    $.getJSON('collate/sendName', data, function(data) { return true; });
}

function setLang( lang ) {
    var data = {};
    data.language = lang;
    $.getJSON('collate/setLanguage', data, function(data) { return true; });
}
    

function submitForm() {
    urls = $('#choosefile').serialize();
    $.getJSON('return_texts', urls,
    function(data) {
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
          url: '/run_toolchain',
          data: query,
          type: 'POST',
          async: false,
          dataType: 'json',
          success: function(resp){
            $('#collatedResult').val( resp.result );
            $('#Resultform').attr( 'action', resp.formaction );
            $('#resultButton').html('');
            $.each( resp.buttons, function( index, value ) {
              $('#resultButton').append( '<div class="button" onclick="submitresult(\'' + index + '\', \'' + value + '\');"><span>' + value + '</span></div>');
            });
          }
        });
    } else {
        showErrorConsole( 'The sigla provide are not unique. Please correct and try again.')
    }
    $('#ajax-loader').css( 'visibility', 'hidden' );
}

function submitresult(name, value) {
    $('#result_submit_button').attr('name', name);
    $('#result_submit_button').attr('value', value);
    $('#Resultform').submit();
}

function showErrorConsole( error_text ) {
    error_console = $("#error_console");
    error_console.empty(); 
    error_console.show();
    error_console.append('<div class="ajax_error">Uhoh, the service returned an error&hellip;<br/> ' + error_text + '</div>');
    error_console.delay(8000).fadeOut(1000);
}

$(document).ready(function(e) {
    $('#collatedResult').val('');
    $("#error_console").ajaxError(function(event, request, settings){
        showErrorConsole( request.responseText );
    });
});

