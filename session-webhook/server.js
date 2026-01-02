const express = require('express');
const morgan = require('morgan');
const axios = require("axios");
const crypto = require('crypto');
require('dotenv').config();
const app = express();
const port = process.env.PORT || 3001;

app.use(express.json({
   verify: (req, res, buf) => {
       req.rawBody = buf.toString('utf8');
   }
}));
app.use(morgan('tiny'));

// Health check endpoint
app.get('/', (req, res) => {
    res.send('Session management webhook is running!');
});

app.get('/health', (req, res) => {
    res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.post('/session/manage', async (req, res) => {
   console.log('=== WEBHOOK RECEIVED ===');
   
   // Get the webhook signature
   const signatureHeader = req.headers['zitadel-signature'];
   if (!signatureHeader) {
       console.error("Missing signature");
       return res.status(400).send('Missing signature');
   }

   // Validate the webhook signature
   const SIGNING_SECRET = process.env.SIGNING_KEY;
   const elements = signatureHeader.split(',');
   const timestamp = elements.find(e => e.startsWith('t=')).split('=')[1];
   const signature = elements.find(e => e.startsWith('v1=')).split('=')[1];
   const signedPayload = `${timestamp}.${req.rawBody}`;
   const hmac = crypto.createHmac('sha256', SIGNING_SECRET)
       .update(signedPayload)
       .digest('hex');

   const isValid = crypto.timingSafeEqual(
       Buffer.from(hmac),
       Buffer.from(signature)
   );

   if (!isValid) {
       console.error("Invalid signature");
       return res.status(400).send('Invalid signature');
   }

   // Configuration
   const PAT = process.env.PAT;
   const CS = parseInt(process.env.CONCURRENT_SESSIONS) || 2;
   const instanceURL = process.env.INSTANCE_URL;

   const body = req.body;
   const userID = body.request.checks.user.userId;

   // Query sessions for this user
   let data = {
       "queries": [
           {
               "userIdQuery": {
                   "id": `${userID}`
               }
           }
       ]
   };

   try {
       const response = await axios.post(`${instanceURL}/v2/sessions/search`, data, {
           headers: {
               'Content-Type': 'application/json',
               'Authorization': `Bearer ${PAT}`
           }
       });

       const sortedSessions = response.data.sessions.sort((a, b) => {
           return new Date(b.creationDate) - new Date(a.creationDate);
       });

       console.log(`User ${userID} has ${sortedSessions.length} active sessions. Limit: ${CS}`);

       // Check if session limit exceeded
       if (sortedSessions.length > CS) {
           console.error(`Session limit reached for user ${userID}. Current: ${sortedSessions.length}, Limit: ${CS}`);
           
           // Delete the newest session (the one just created)
           const newestSession = sortedSessions[0];
           console.log(`Deleting newest session ID: ${newestSession.id}`);
           await axios.delete(`${instanceURL}/v2/sessions/${newestSession.id}`, {
               headers: {
                   Authorization: `Bearer ${PAT}`,
                   'Content-Type': 'application/json'
               }
           });
           
           return res.status(400).json({
               error: 'Session limit reached',
               message: `You have reached the maximum number of concurrent sessions (${CS}). Please log out from another device first.`,
               currentSessions: sortedSessions.length - 1
           });
       }
   } catch (error) {
       console.error('Error:', error.response?.data || error.message);
       return res.status(500).json({
           error: 'Internal server error',
           message: error.message
       });
   }

   res.status(200).send('OK');
});

app.listen(port, () => {
   console.log(`Session webhook listening at http://localhost:${port}`);
});
