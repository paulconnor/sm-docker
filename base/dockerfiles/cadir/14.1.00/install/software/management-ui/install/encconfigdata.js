
/*
 * This script is used to encode the passwords in config files for upgrade use case.
 * The passwords are encrypted using dxpassword tool with CADIR encryption.
 * The scrypt also keeps the original file as backup in encryption.
 * If the passwords are already encrypted the script does not update anything.  
*/
 
const fs = require('fs');

function ReadConfigData(fname)
{
    var configdata  = require(fname);
  
    return configdata;
}

function UpdateData(fdata, instrdata, encstrdata, sstr)
{
    var instr = '\'' + instrdata + '\'';
    var encstr =  '\''+encstrdata+'\'';
    var idx = 0;
    var cnt = 0;
	
    while(1)
    {
	idx = fdata.data.indexOf(instr, idx);
	if(idx == -1)
	{
	    break;
	}
	idx++;
	cnt ++;
    }
    if(cnt == 1)
    {
	fdata.data = fdata.data.replace(instr, encstr);
    }
    else if(cnt != 0)
    {
	var rexp = new RegExp(sstr+'\\s*:\\s*', 'gm');
	var exparr = fdata.data.match(rexp);
	var count = exparr.length;
	if(count != 0)
	{
	    for(var c= 0;c<count;c++)
	    {
		fdata.data = fdata.data.replace(exparr[c]+instr , sstr+': '+encstr);
	    }
	}
    }
}

function EncodeConfigCredData(cdata, fdata)
{
    const execSync = require('child_process').execSync;
    var encoded = false;
    var encstr;

    cdata.ldapClientConfig.forEach(function(oneLdapClientConfig) 
    {
	if(oneLdapClientConfig.bindCredentials.indexOf('{CADIR}')!=0)
	{
	    encstr = execSync('dxpassword -P CADIR ' + oneLdapClientConfig.bindCredentials).toString();
	    UpdateData(fdata, oneLdapClientConfig.bindCredentials, encstr, 'bindCredentials');
	    encoded = true;
	}
    });
    if(cdata.externalMonitor && cdata.externalMonitor.password.indexOf('{CADIR}')!=0)
    {
	encstr  = execSync('dxpassword -P CADIR ' + cdata.externalMonitor.password).toString();
	UpdateData(fdata, cdata.externalMonitor.password, encstr, 'password');
	encoded = true;
    }
    return encoded;
}

function EncodeScimConfigCredData(cdata, fdata)
{
    const execSync = require('child_process').execSync;
    var encoded = false;
    if(cdata.mgmtServerConnection.password.indexOf('{CADIR}')!=0)
    {
	var encstr = execSync('dxpassword -P CADIR ' + cdata.mgmtServerConnection.password).toString();
	UpdateData(fdata, cdata.mgmtServerConnection.password, encstr, 'password');
	encoded = true;
    }
    return encoded;
}

function EncryptConfigFile(fname)
{
    const crypto = require('crypto');

    try {
	const algorithm = 'aes256';
	const password = 'C@D1r3ct0ry';
	const key = crypto.createHash('sha256').update(password).digest();
	const iv = Buffer.alloc(16, 0); // Initialization vector.

	const cipher = crypto.createCipheriv(algorithm, key, iv);
	const fdata = fs.readFileSync(fname, {encoding:'utf8', flag:'r'}); 

	var encrypted = cipher.update(fdata, 'utf8', 'hex');
	encrypted += cipher.final('hex');
	    
	fs.writeFileSync(fname+'.enc', encrypted);
	console.log('Config file encrypted'); 
    }catch(err) {
	// An error occurred
	console.error(err);
    }
}

function DecryptConfigFile(fname)
{
    const crypto = require('crypto');

    try {
	const algorithm = 'aes256';
	const password = 'C@D1r3ct0ry';
	const key = crypto.createHash('sha256').update(password).digest();
	const iv = Buffer.alloc(16, 0); // Initialization vector.

	const decipher = crypto.createDecipheriv(algorithm, key, iv);

	const fdata = fs.readFileSync(fname+'.enc', {encoding:'utf8', flag:'r'}); 
	// Decrypted using same algorithm, key and iv.
	var decrypted = decipher.update(fdata, 'hex', 'utf8');
	decrypted += decipher.final('utf8');
	fs.writeFileSync(fname+'.dec', decrypted);
	console.log('Config file decrypted'); 
    }catch(err) {
	// An error occurred
	console.error(err);
    }
}

function EncodeConfig()
{
    var cdata;
    var enc;
    var retval = 0;
    var fdata = { data: ''};
    var fname, fullfname;
    try 
    {
	fname = 'config';
	fullfname = fname + '.js';
	if (fs.existsSync(fullfname)) 
	{
	    cdata = ReadConfigData('./' + fname);
	    fdata.data = fs.readFileSync(fullfname, {encoding:'utf8', flag:'r'});
	    enc = EncodeConfigCredData(cdata, fdata);
	    if(enc)
	    {
		EncryptConfigFile(fullfname);
		// DecryptConfigFile(fullfname);
		fs.writeFileSync(fullfname, fdata.data);
		retval += 1;
	    }
	}
    }
    catch(err) {
    // An error occurred
	console.error('Error occured in encrypting config data');
	console.error(err);
    }

    try 
    {
	fname = 'config-scim';
	fullfname = fname + '.js';

	if(fs.existsSync(fullfname))
	{
	    cdata = ReadConfigData('./'+ fname);
	    fdata.data = fs.readFileSync(fullfname, {encoding:'utf8', flag:'r'});
	    enc = EncodeScimConfigCredData(cdata, fdata);
	    if(enc)
	    {
		EncryptConfigFile(fullfname);
		// DecryptConfigFile(fullfname);
		fs.writeFileSync(fullfname, fdata.data);
		retval += 2;
	    }
	}
    }
    catch(err) {
    // An error occurred
	console.error('Error occured in encrypting config-scim data');
	console.error(err);
    }
    process.exit(retval);
}
EncodeConfig();
