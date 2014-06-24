/*
 * Dieses Programm testet die DmWebLib
 */
using DmWebLib;
using Gtk;
using WebKit;

public void main( string[] argv )
{
  Gtk.init( ref argv );

  Server srv = new Server( 10000 );
  srv.add_resource_dir( "/res", "../src" );
  srv.add_callback( "/echo", echo );
  srv.run( );
  
  show_window( );
  
  Gtk.main( );
}

public WebServer.Response echo(
                    Server server,
                    WebServer.Request request,
                    DataInputStream dis
                  )
{
  WebServer.Response response = new WebServer.Response( );
  string response_text = "";
  foreach ( string key in request.args.get_keys( ) )
  {
    unowned string? text = request.args[ key ];
    if ( text == null )
    {
      text = "(null)";
    }
    response_text += key + "=" + text + "\n";
  }
  response.text = response_text;
  response.content_type = "text/plain";
  return response;
}

public void show_window( )
{
  Window w = new Window( );
  w.title = "DMWebLib Test";
  w.destroy.connect (Gtk.main_quit);
  WebView wv = new WebView( );
  wv.settings.enable_default_context_menu = false;
  VBox vbox = new VBox( false, 0 );
  vbox.add( wv );
  
  HBox buttons = new HBox( false, 0 );
  Button b = new Button.with_label( "Filesystem" );
  b.clicked.connect( ( ) => {
    wv.open( "http://localhost:10000/res/index.html" );
  } );
  buttons.add( b );
  vbox.add( buttons );
  
  w.add( vbox );
  w.show_all( );
}

