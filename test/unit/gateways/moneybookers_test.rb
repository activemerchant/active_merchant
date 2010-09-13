# -*- coding: utf-8 -*-
require File.dirname(__FILE__) + '/../../test_helper'
class MoneybookersTest < Test::Unit::TestCase
  def setup
    @amount = 100
    @options = {
      :pay_to_email => 'seller_test@urbanvention.com',
      :billing_address => address,
      :return_url      => 'localhost:3000/payment_confirmed',
      :cancel_url      => 'localhost:3000/payment_canceled',
      :language        => "DE",
      :notify_url      => 'localhost:3000/notify_payment_success',
      :detail1_description => "Bestellnummer: ",
      :detail1_text    => "FooBar123"
    }
    @gateway = MoneybookersGateway.new(@options)
  end

  def test_currency_defaults_to_euro
    assert_equal "EUR", @gateway.instance_eval {currency}
  end

  def test_billing_address_present
    assert @options[:billing_address]
  end

  def test_successful_purchase_setup
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.setup_purchase(@amount)
    assert response.success?
    assert response.token =~ /\w{32}/
  end

  def test_amount_method
    cents = 1000
    assert_equal "10.00", @gateway.instance_eval {amount(cents)}
  end

  def test_successful_purchase_setup_provides_checkout_url
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.setup_purchase(@amount)
    assert_false @gateway.checkout_url.nil?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    assert response = @gateway.setup_purchase(@amount)
    assert_failure response
  end

  private

  def successful_purchase_response
    "b30507717219e01892e5c238c559a7f7"
  end

  # Place raw failed response from gateway here
  # this one happens with a wrong currency
  def failed_purchase_response
    <<-RESPONSE
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
<head>

<script type="text/javascript">
    function LoaderDispatch ( show, force ) {
        if ( ! force ) return;
        var arr = [ 'loader_back_id', 'loader_popup_id' ];
        for ( var i in arr ) {
            var obj = document.getElementById( arr[i] );
            if ( obj ) obj.style.display = show ? 'block' : 'none';
        }
        return true;
    }
</script>
<noscript></noscript>

<style type="text/css" media="screen">
    html, body { padding:0px !important; margin:0px !important; }
    body { height:100% !important; }

    .loader_cover {
        display:none; z-index:1000;
        position:fixed; _position:absolute;
        top:0px; left:0px; width:100%; height:100%;
    }
    .loader_back {
        display:none; z-index:2000;
        background-color:#fff;
    }
    .loader_popup {
        display:none; z-index:3000;
    }
    .loader_popup_position {
        position:absolute;
        top:0%; left:50%;
        width:0px; height:0px;
    }
    .loader_popup_message {
        position:relative;
        height:100px; width:200px; padding-top:25px;
        top:0px; left:-100px;
        line-height:40px !important;
        color:#bbb; background-color:#fff; text-align:center;
        font:bold 18px Arial,Helvetica,sans-serif;
    }

    #loader_wrapper_id { height: 100%; }
    #loader_clear_id { clear: both; height: 0px; overflow: hidden; }
</style>

<script type="text/javascript">
    document.write('\
<div id="loader_back_id" class="loader_cover loader_back"></div>\
<div id="loader_popup_id" class="loader_cover loader_popup">\
    <div class="loader_popup_position">\
        <div class="loader_popup_message">\
            Bitte warten ...<br /><img src="/images/loader/gw-loading.gif" alt="" />\
        </div>\
    </div>\
</div>\
    ');
</script>
<noscript></noscript>

<script type="text/javascript"> LoaderDispatch(true,true); </script>
<noscript></noscript>

<title>moneybookers.com</title>

<meta http-equiv="Content-Type" content="text/html; charset=utf-8">

<meta name="Author" content="Moneybookers ltd.">
<meta name="Publisher" content="Moneybookers ltd.">
<meta name="Copyright" content="Moneybookers ltd.">
<meta name="robots" content="all,index,follow" />
<meta name="distribution" content="global" />
<meta name="rating" content="general" />


    <link rel="icon" href="https://www.moneybookers.com/favicon.ico" type="image/vnd.microsoft.icon" />
<link rel="styleSheet" href="https://www.moneybookers.com/css/style_de.css" type="text/css" media="screen">



    <link rel="styleSheet" href="https://www.moneybookers.com/css/onboarding.css" type="text/css" media="screen">


    <link rel="styleSheet" href="https://www.moneybookers.com/css/gw/default/style.css" type="text/css" media="screen" />
    <link rel="styleSheet" href="https://www.moneybookers.com/css/gw/default/btn.css" type="text/css" media="screen" />
    
    <script type="text/javascript">
function ServerDate() {
    //return server date as javascript Date object
    return new Date(2010, 9 - 1, 13);
}
</script>
<script type="text/javascript" src="https://www.moneybookers.com/main.js"></script>
<script type="text/javascript" src="https://www.moneybookers.com/ourlib.js"></script>
<script type="text/javascript" src="https://www.moneybookers.com/regexp.js"></script>
<script type="text/javascript" src="https://www.moneybookers.com/swfobject.js"></script>    <script type="text/javascript" src="https://www.moneybookers.com/js/jquery.js"></script>

<script type="text/javascript" src="https://www.moneybookers.com/js/jqplugins/qtip/mb.jquery.qtip.min.js"></script>
<script type="text/javascript">
    
    // define variables that can be used from any script for specific reason
    var hint_anchors = new Array();
</script>





    <script language="Javascript" src="https://www.moneybookers.com/js/gw.js"></script> 

    <script>
        var mbcookie = getCookie("SESSION_ID");
        if (mbcookie==null||mbcookie.length==0||navigator.cookieEnabled==0){
            $(document).ready(function() {
                $("body").html($("#mbcookie").html());
            });
        }
    </script>
</head>
<body >

<!-- START: loader -->
<div id="loader_wrapper_id">

    <!-- START: gateway content -->
    <div id="gw_content_wrapper">

<script language="Javascript">
    function get_turing_info() {
        return "<b>Was hat es mit der Sicherheitsnummer auf sich?</b><br/>Die Eingabe der Sicherheitsnummer während der Anmeldung soll automatisierte, unbefugte Anmeldungen bei Ihrem Konto verhindern. Zum Fortfahren muss eine als Bild angezeigte Zufallszahl korrekt eingegeben werden.";
    }
</script>

<script language="Javascript" src="https://www.moneybookers.com/ourlib.js"></script>
<div id="ourDiv" width="1" style="position:absolute; visibility:hidden; z-index:2;"></div>


<div id="preloader" class="preloader">    <img src="https://www.moneybookers.com/images/default/btn_right_disabled.gif" height="1" width="1" />
    <img src="https://www.moneybookers.com/images/default/btn_right2.gif" height="1" width="1" />
    <img src="https://www.moneybookers.com/images/default/btn_right.gif" height="1" width="1" />
    <img src="https://www.moneybookers.com/images/default/btn_left_disabled.gif" height="1" width="1" />
    <img src="https://www.moneybookers.com/images/default/btn_left2.gif" height="1" width="1" />
    <img src="https://www.moneybookers.com/images/default/btn_left.gif" height="1" width="1" /></div>
<div id="logo_area">        <div class="logo_spacer"/>           
</div>

<form name="changeamount" action="payment.pl">    
<div id="payment_info_expanded"  style="display:none" >    <div class="pay_to" title="Zahlung an seller_test@urbanvention.com" >Zahlung an seller_test@urbanvention.com</div>            <dl class="row">
                <dd class="col1">Bestellnummer:</dd>
                <dd class="col2">FooBar123</dd>
                <dd class="col3">&nbsp;</dd>
                <dd class="col4">&nbsp;</dd>
            </dl>            <div>
                <dl class="total" title="ZAHLUNGSSUMME">
                    <dd>ZAHLUNGSSUMME                :</dd><dd class="price">100.00&nbsp;       </dd>                     </dl>
            </div>        <div class="collapse_area">
            <a href="javascript:more_info(0);" class="collapse" title="Für weniger Informationen – Feld verkleinern"><span class="less_info">Weniger Informationen</span><strong>Für weniger Informationen – Feld verkleinern</strong></a>
        </div>
</div>            
<div id="payment_info_folded" style="">  <div class="pay_to" title="Zahlung an seller_test@urbanvention.com">Zahlung an seller_test@urbanvention.com</div>  <dl class="total" title="ZAHLUNGSSUMME">
        <dd>ZAHLUNGSSUMME                :</dd><dd class="price">100.00&nbsp;       </dd>      </dl>  <div class="expand_area"><a href="javascript:more_info(1);" class="expand" title="Für mehr Informationen – Feld vergrößern"><span class="more_info">Mehr Informationen</span><strong>Für mehr Informationen – Feld vergrößern</strong></a></div>
</div>        

</form>            

<script language="JavaScript">
    function more_info (show) {                 
        if ( $("#payment_info_folded") != null && $("#payment_info_expanded") != null) {
            if ( show == 1) {            
                $("#payment_info_folded").slideUp('fast',function (){
                   $("#payment_info_expanded").slideDown('slow');
                });
            } else {                           
                $("#payment_info_expanded").slideUp('slow',function (){
                    $("#payment_info_folded").slideDown('fast');
                });
            }        
        }
    }
    
    var init_rec_amount = '';
    function calculate_total_amount( new_send_amount ){
        var total_amount_rec = getObject('total_amount_rec');
        if ( total_amount_rec != null && typeof(total_amount_rec) != 'undefined' ) {
            var new_total_amount = init_rec_amount*1 + new_send_amount*1;
            lwr(to_money(new_total_amount) + ' ', 'total_amount_rec');
        }
    } </script>
 

<script language="Javascript">
    function get_turing_info() {
        return "<b>Was hat es mit der Sicherheitsnummer auf sich?</b><br/>Die Eingabe der Sicherheitsnummer während der Anmeldung soll automatisierte, unbefugte Anmeldungen bei Ihrem Konto verhindern. Zum Fortfahren muss eine als Bild angezeigte Zufallszahl korrekt eingegeben werden.";
    }
</script>

<script language="Javascript" src="https://www.moneybookers.com/ourlib.js"></script>
<div id="ourDiv" width="1" style="position:absolute; visibility:hidden; z-index:2;"></div>

    <h1 class="title" style=>Transaktion nicht erlaubt      </h1>    <div class="gateway_content">                <dl>
            <dd>Die vom Händler gewählte Währung für diese Zahlung wird von Moneybookers nicht unterstüzt. Bitte kontaktieren Sie ihren Händler um Unterstützung zu erhalten.</dd> 
            <dd><div class="separator" id="separator"></div>
<dl class="buttons">    <dd ><button type="button" 
        class="submit_btn"
        value="Abbrechen"            onclick="top.location='localhost:3000/payment_canceled';">
<span class="msg">ABBRECHEN</span></button>    </dd></dl>                                              </dd>
        </dl>    </div><div id="mbcookie" style="display:none">    <div class="gateway_content">    <dl>          <dd>Bitte aktivieren Sie Ihre Cookies, damit Sie Moneybookers in vollem Umfang nutzen können.

Um Ihre Bezahlung an  abzuschließen, müssen Sie Cookies von Moneybookers in den Einstellungen Ihres Browsers akzeptieren. Falls Sie Ihre Zugriffsrechte über die Software eines Drittherstellers verwalten, erlauben Sie dort bitte Cookies von Moneybookers um Ihre Transaktion erfolgreich durchzuführen.</dd>    </dl>        
    <dl>
        <dd><div class="separator" id="separator"></div>
<dl class="buttons">    <dd ><button type="button" 
        class="submit_btn"
        value="Weiter"            onclick="location.replace('https://www.moneybookers.com/app/payment.pl?sid=eb9e98f3dc5e70dda4e03834f35aa72b');">
<span class="msg">WEITER</span></button>    </dd></dl>                                             </dd>
       </dl>    </div></div>

<script language="JavaScript">                        repositionHints();//attach hints (if any) to anchors elements

</script>

<!-- basename: payment, template_name: error -->
<script type="text/javascript" src="/js/tracker/init.js">/**/</script>
<script type="text/javascript"> customTracker( { _upage: '/de/payment/error' } ); </script>

</div>
<!-- END: gateway content -->

<!-- END: loader -->
    <div id="loader_clear_id"></div>
</div>

<script type="text/javascript"> setTimeout( function () { LoaderDispatch(false,true); }, 200 ); </script>
<noscript></noscript>

</body>
</html>
RESPONSE
  end
end
