
import com.ca.siteminder.sdk.agentapi.SmRegHost;
import com.ca.siteminder.sdk.agentapi.Util; 
import com.netegrity.util.Fips140Mode;

 
class RegisterApp {    
//public class RegisterApp {    
 
    private static final int EXIT_FAILURE = -1;
    private static final int EXIT_SUCCESS = 0;

    public static void main(String[] args) {    
 
        Fips140Mode fipsMode = Fips140Mode.getFips140ModeObject();    
     
        //Set the Fips Mode after reading it from the env variable    
        fipsMode.setMode(Util.resolveSetting());
     
        int status = EXIT_FAILURE;
        
        String address = System.getProperty("address");
        String filename = System.getProperty("fileName");
        String hostname = System.getProperty("hostName");
        String hostconfig = System.getProperty("hostConfig");
        String username = System.getProperty("userName");
        String password = System.getProperty("password");
     
        boolean bRollover = false;    
        boolean bOverwrite = true;    
     
        SmRegHost reghost = new SmRegHost(address, filename,hostname,hostconfig,username,password,bRollover,bOverwrite);
        try { 
            reghost.register();        
            status = EXIT_SUCCESS;    
            }
     
        catch (Exception e)
           {         
              e.printStackTrace();    
           }    
     
        finally
           { //The Method close() is available only in Release 12.7 and higher.         
             //reghost.close();     
           }
     
        System.out.println(reghost.getSharedSecret()); // the cleartext shared secret is displayed     
        System.exit(status);    
    }
     
 }
     
