var MWJ_progBar = 0;

function getRefToDivNest( divID, oDoc ) {
	if( !oDoc ) { oDoc = document; }
	//if( document.layers ) {
		//if( oDoc.layers[divID] ) { return oDoc.layers[divID]; } else {
			//for( var x = 0, y; !y && x < oDoc.layers.length; x++ ) {
				//y = getRefToDivNest(divID,oDoc.layers[x].document); }
		//	return y; } }
	//if( document.getElementById ) { 
	return document.getElementById(divID);
	// }
	//if( document.all ) { return document.all[divID]; }
	//return document[divID];
}

function progressBar(oId, oBt, oBc, oBg, oBa, oBgi, oBi, oPd, oPl, oWi, oHi, oDr ) {
	MWJ_progBar++; this.id = 'MWJ_progBar' + MWJ_progBar; this.dir = oDr; this.width = oWi; this.height = oHi; this.amt = 0;
	//write the bar as a layer in an ilayer in two tables giving the border
	holder_el = document.getElementById(oId);
	var html_to_insert = '';
	html_to_insert += '<table border="0" cellspacing="0" cellpadding="'+oBt+'"><tr><td bgcolor="'+oBc+'">'+
		'<table border="0" cellspacing="0" cellpadding="0"><tr><td height="'+oHi+'" width="'+oWi+'" bgcolor="'+oBg+'" style="background-image : url('+oBi+'); background-repeat : repeat;">';
	if( document.layers ) {
		html_to_insert += '<ilayer height="'+oHi+'" width="'+oWi+'"><layer bgcolor="'+oBa+'" name="MWJ_progBar'+MWJ_progBar+'"></layer></ilayer>';
	} else {
		html_to_insert += '<div style="position:relative;top:0px;left:0px;height:'+oHi+'px;width:'+oWi+'px;">'+
			'<div style="position:absolute;top:0px;left:0px;height:'+oHi+'px;width:'+oWi+'px;font-size:14px;text-align:center;font-weight:bolder;z-index:4999;font-family:Arial;color:'+oPd+';line-height:'+oHi+'px;" id="MWJ_progBar'+MWJ_progBar+'_perc"></div>'+
			'<div style="position:absolute;top:0px;left:0px;height:'+oHi+'px;width:'+oWi+'px;font-size:14px;text-align:center;font-weight:bolder; z-index:5001;font-family:Arial;color:'+oPl+';line-height:'+oHi+'px;" id="MWJ_progBar'+MWJ_progBar+'_perc2"></div>'+
			'<div style="position:absolute;top:0px;left:0px;height:'+oHi+'px;width:'+oWi+'px;font-size:1px;background-image:url('+oBgi+'); background-repeat : repeat;z-index:5000;background-color:'+oBa+';" id="MWJ_progBar'+MWJ_progBar+'"></div></div>' ; 
	}
	html_to_insert += '</td></tr></table></td></tr></table>\n';
	holder_el.innerHTML = html_to_insert;
	this.setBar = resetBar; //doing this inline causes unexpected bugs in early NS4
	this.setCol = setColour;
}
function resetBar( a, b ) {
	//work out the required size and use various methods to enforce it
	this.amt = ( typeof( b ) == 'undefined' ) ? a : b ? ( this.amt + a ) : ( this.amt - a );
	if( isNaN( this.amt ) ) { this.amt = 0; } if( this.amt > 1 ) { this.amt = 1; } if( this.amt < 0 ) { this.amt = 0; }
	var theWidth = Math.round( this.width * ( ( this.dir % 2 ) ? this.amt : 1 ) );
	var theHeight = Math.round( this.height * ( ( this.dir % 2 ) ? 1 : this.amt ) );
	var theDiv = getRefToDivNest( this.id ); if( !theDiv ) { window.status = 'Progress: ' + Math.round( 100 * this.amt ) + '%'; return; }
	var theOtherDiv = getRefToDivNest( this.id + '_perc' );
	var theOtherDiv2 = getRefToDivNest( this.id + '_perc2' );
	theOtherDiv.innerHTML = Math.round(this.amt*100)+ '%';
	theOtherDiv2.innerHTML = Math.round(this.amt*100)+ '%';
	var oPix = document.childNodes ? 'px' : 0;
	var text = '';
	switch(this.dir)
		{
			case 1: text = 'rect(0px '+theWidth+'px '+theHeight+'px 0px)'; break;
			case 2: text = 'rect(0px '+theWidth+'px '+theHeight+'px 0px)'; break;
			case 3: text = 'rect(0px '+this.width+ 'px '+theHeight+'px '+(this.width-theWidth)+'px )'; break;
			case 4: text = 'rect('+(this.height-theHeight)+'px '+this.width+ 'px '+this.height+'px 0px )'; break;
		}
	theOtherDiv2 = theOtherDiv2.style; theOtherDiv2.clip = text;
	
	
	var text = '';
	switch(this.dir)
		{
			case 1: text = 'rect(0px '+theWidth+'px '+theHeight+'px 0px)'; break;
			case 2: text = 'rect(0px '+theWidth+'px '+theHeight+'px 0px)'; break;
			case 3: text = 'rect(0px '+this.width+ 'px '+theHeight+'px '+(this.width-theWidth)+'px )'; break;
			case 4: text = 'rect('+(this.height-theHeight)+'px '+this.width+ 'px '+this.height+'px 0px )'; break;
		}
	theDiv = theDiv.style; theDiv.clip = text;
	 
	/*
	if( theDiv.style ) { theDiv = theDiv.style; theDiv.clip = 'rect(0px '+theWidth+'px '+theHeight+'px 0px)'; }
	theDiv.width = theWidth + oPix; theDiv.pixelWidth = theWidth; theDiv.height = theHeight + oPix; theDiv.pixelHeight = theHeight;
	if( theDiv.resizeTo ) { theDiv.resizeTo( theWidth, theHeight ); }
	theDiv.left = ( ( this.dir != 3 ) ? 0 : this.width - theWidth ) + oPix; theDiv.top = ( ( this.dir != 4 ) ? 0 : this.height - theHeight ) + oPix;
	*/

}
function setColour( a ) {
	//change all the different colour styles
	var theDiv = getRefToDivNest( this.id ); if( theDiv.style ) { theDiv = theDiv.style; }
	theDiv.bgColor = a; theDiv.backgroundColor = a; theDiv.background = a;
}

function d2h(d) {return d.toString(16);}
