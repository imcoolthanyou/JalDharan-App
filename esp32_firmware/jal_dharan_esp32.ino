/**
 * Jal Dharan ESP32 - MASTER PRODUCTION VERSION 
 * (Includes pH 2.30V Bypass, Toggle Debounce, Waterproof Sonar Fix,
 *  and /info JSON endpoint for Flutter app provisioning)
 */

#include <Wire.h> 
#include <LiquidCrystal_I2C.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <WebServer.h>
#include <DNSServer.h> 
#include <Preferences.h> 

// ==========================================
// 1. PIN DEFINITIONS
// ==========================================
#define TRIG_PIN 5
#define ECHO_PIN 18
#define FLOW_PIN 4
#define TDS_PIN 34
#define PH_PIN 35
#define MOISTURE_PIN 39     // Moisture Sensor on VN (GPIO 39)
#define MOTOR_PIN_1 26      // Wired to L298N IN3
#define MOTOR_PIN_2 27      // Wired to L298N IN4
#define SWITCH_PIN 13       
#define BOOT_BUTTON 0       

// ==========================================
// 2. CONFIGURATION
// ==========================================
// Update this to your actual Vercel/Cloud URL if it changes
//static const String baseUrl = "http://10.111.44.219:8000";
static const String baseUrl = "http://10.50.236.219:8000";
const byte DNS_PORT = 53;

// ==========================================
// 3. GLOBALS & OBJECTS
// ==========================================
LiquidCrystal_I2C lcd(0x27, 16, 2);
Preferences preferences;
WebServer server(80);
DNSServer dnsServer;

// State
bool isProvisioned = false;
String ssid = "";
String password = "";

// Sensor Data
volatile int flowPulseCount = 0;
float flowRate = 0.0;
unsigned long oldTime = 0;
unsigned long lastSwitchTime = 0;
int displayState = 0; 

// DATA VARIABLES
float currentDistance = 0;
float currentFlow = 0;
float currentTDS = 0;
float currentPH = 0;
float currentMoisture = 0; 
String motorStatus = "OFF";

// Pump Control State
bool cloudCommand = false; 
int lastSwitchState = HIGH; 

// ==========================================
// 4. HTML FORM & WIFI HANDLERS
// ==========================================
const char* htmlForm = R"rawliteral(
<!DOCTYPE HTML><html><head>
  <title>Jal Dharan Setup</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
</head><body>
  <h2>Jal Dharan Setup</h2>
  <form action="/save" method="POST">
    <input type="text" name="ssid" placeholder="WiFi Name (SSID)">
    <input type="password" name="pass" placeholder="WiFi Password">
    <button type="submit">Connect Device</button>
  </form>
</body></html>)rawliteral";

void IRAM_ATTR pulseCounter() { flowPulseCount += 1; }
void handleRoot() { server.send(200, "text/html", htmlForm); }

// ── /info — Returns JSON with MAC for Flutter app provisioning ─────────────
// IMPORTANT: This MUST be registered BEFORE onNotFound so it takes priority
// over the captive portal redirect.
void handleInfo() {
  String json = "{\"esp_mac\":\"" + WiFi.macAddress() + "\"}";
  server.send(200, "application/json", json);
}

void handleSave() {
  String n_ssid = server.arg("ssid");
  String n_pass = server.arg("pass");
  if (n_ssid.length() > 0) {
    server.send(200, "text/html", "<h1>Saved! Restarting...</h1>");
    delay(500);
    preferences.begin("wifi_config", false);
    preferences.putString("ssid", n_ssid);
    preferences.putString("pass", n_pass);
    preferences.end();
    ESP.restart(); 
  } else { server.send(400, "text/plain", "Missing SSID"); }
}

void handleNotFound() { server.sendHeader("Location", "/", true); server.send(302, "text/plain", ""); }

// ==========================================
// 5. SETUP & LOOP
// ==========================================

void setup() {
  Serial.begin(115200);
  lcd.init(); lcd.backlight();
  
  pinMode(TRIG_PIN, OUTPUT); 
  pinMode(ECHO_PIN, INPUT);
  pinMode(FLOW_PIN, INPUT_PULLUP);
  pinMode(MOTOR_PIN_1, OUTPUT); 
  pinMode(MOTOR_PIN_2, OUTPUT);
  pinMode(SWITCH_PIN, INPUT_PULLUP);
  pinMode(BOOT_BUTTON, INPUT_PULLUP);
  pinMode(MOISTURE_PIN, INPUT); 
  
  digitalWrite(MOTOR_PIN_1, LOW); 
  digitalWrite(MOTOR_PIN_2, LOW);
  attachInterrupt(digitalPinToInterrupt(FLOW_PIN), pulseCounter, RISING);

  preferences.begin("wifi_config", true);
  ssid = preferences.getString("ssid", "");
  password = preferences.getString("pass", "");
  preferences.end();

  if (ssid == "") {
    WiFi.mode(WIFI_AP);
    WiFi.softAP("JalDharan_Setup", "");
    dnsServer.start(DNS_PORT, "*", WiFi.softAPIP());
    server.on("/", handleRoot);
    server.on("/save", handleSave);
    server.on("/info", handleInfo);   // ← NEW: JSON endpoint for Flutter app (BEFORE onNotFound)
    server.onNotFound(handleNotFound);
    server.begin();
    lcd.clear(); lcd.print("Setup Required");
  } else {
    isProvisioned = true;
    lcd.clear(); lcd.print("Connecting...");
    WiFi.begin(ssid.c_str(), password.c_str());
    int retries=0; while(WiFi.status() != WL_CONNECTED && retries < 20){ delay(500); retries++; }
    if(WiFi.status() == WL_CONNECTED) { 
      lcd.clear(); lcd.print("Connected!"); 
      delay(1000);
    }
  }
}

void runSensorLogic();
void updateDisplay();
void readSensors();
void sendDataToBackend();

void loop() {
  // Factory Reset via Boot Button
  if(digitalRead(BOOT_BUTTON)==LOW) {
    delay(100);
    if(digitalRead(BOOT_BUTTON)==LOW) {
      preferences.begin("wifi_config", false); preferences.clear(); preferences.end(); ESP.restart();
    }
  }

  if (!isProvisioned) { dnsServer.processNextRequest(); server.handleClient(); } 
  else { runSensorLogic(); updateDisplay(); }
}

// ==========================================
// 6. MAIN LOGIC
// ==========================================
void runSensorLogic() {
  int currentSwitchState = digitalRead(SWITCH_PIN);

  // --- 1. EDGE DETECTION (Physical Toggle Switch) ---
  if (currentSwitchState != lastSwitchState) {
    delay(50); // Debounce delay
    currentSwitchState = digitalRead(SWITCH_PIN); // Read again to confirm
    
    if (currentSwitchState == lastSwitchState) { // If it's a genuine flip
      if (currentSwitchState == LOW) { // Switch Flipped ON
        digitalWrite(MOTOR_PIN_1, HIGH); digitalWrite(MOTOR_PIN_2, LOW); motorStatus = "ON";
        cloudCommand = true; 
      } else { // Switch Flipped OFF
        digitalWrite(MOTOR_PIN_1, LOW); digitalWrite(MOTOR_PIN_2, LOW); motorStatus = "OFF";
        cloudCommand = false; 
      }
    }
    lastSwitchState = currentSwitchState; 
  }
  // --- 2. CLOUD BOSS (No Physical Edge Detected) ---
  else {
    if (cloudCommand) {
       digitalWrite(MOTOR_PIN_1, HIGH); digitalWrite(MOTOR_PIN_2, LOW); motorStatus = "ON";
    } else {
       digitalWrite(MOTOR_PIN_1, LOW); digitalWrite(MOTOR_PIN_2, LOW); motorStatus = "OFF";
    }
  }

  // --- 3. SENSOR READING INTERVAL (Every 2 Seconds) ---
  if((millis() - oldTime) > 2000) {
    detachInterrupt(digitalPinToInterrupt(FLOW_PIN));
    flowRate = ((1000.0 / (millis() - oldTime)) * flowPulseCount) / 7.5; 
    oldTime = millis(); flowPulseCount = 0;
    attachInterrupt(digitalPinToInterrupt(FLOW_PIN), pulseCounter, RISING);
    
    currentFlow = flowRate;
    readSensors();
    sendDataToBackend(); 
  }
}

void readSensors() {
  // --- DISTANCE (Waterproof Pulse Fix) ---
  digitalWrite(TRIG_PIN, LOW); delayMicroseconds(5);
  digitalWrite(TRIG_PIN, HIGH); delayMicroseconds(20); 
  digitalWrite(TRIG_PIN, LOW);
  long duration = pulseIn(ECHO_PIN, HIGH, 40000); 
  currentDistance = (duration == 0) ? 0 : duration * 0.034 / 2;

  // --- TDS ---
  float vTDS = analogRead(TDS_PIN) * (3.3 / 4095.0);
  currentTDS = (vTDS < 0.1) ? 0 : (133.42*pow(vTDS,3) - 255.86*pow(vTDS,2) + 857.39*vTDS) * 0.5;
  
  // --- pH (Software Bypass to 2.30V) ---
  float vPH = analogRead(PH_PIN) * (3.3 / 4095.0);
  currentPH = 7.0 + ((2.30 - vPH) / 0.18); 

  // --- MOISTURE ---
  int rawMoisture = analogRead(MOISTURE_PIN);
  currentMoisture = map(rawMoisture, 4095, 1000, 0, 100);
  if (currentMoisture < 0) currentMoisture = 0;
  if (currentMoisture > 100) currentMoisture = 100;
}

void sendDataToBackend() {
  if(WiFi.status() == WL_CONNECTED){
    HTTPClient http;
    http.begin(baseUrl + "/sensor/update");
    http.addHeader("Content-Type", "application/json");

    // Build JSON Payload (Sending 0 for current and voltage safely)
    String jsonPayload = "{";
    jsonPayload += "\"distance\":" + String(currentDistance) + ",";
    jsonPayload += "\"flow_rate\":" + String(currentFlow) + ",";
    jsonPayload += "\"tds\":" + String(currentTDS) + ",";
    jsonPayload += "\"ph\":" + String(currentPH) + ",";
    jsonPayload += "\"current\":0.0,"; 
    jsonPayload += "\"voltage\":0.0,"; 
    jsonPayload += "\"moisture\":" + String(currentMoisture) + ","; 
    jsonPayload += "\"motor_status\":\"" + motorStatus + "\","; 
    jsonPayload += "\"device_mac\":\"" + WiFi.macAddress() + "\""; 
    jsonPayload += "}";

    int httpCode = http.POST(jsonPayload);
    
    if(httpCode > 0) {
       String payload = http.getString();
       if (payload.indexOf("\"pump_command\":\"ON\"") > 0) {
         cloudCommand = true;
       } else if (payload.indexOf("\"pump_command\":\"OFF\"") > 0) {
         cloudCommand = false;
       }
    }
    
    // Cleaned Serial Print (Online)
    Serial.print("Level:");         Serial.print(currentDistance); Serial.print(",");
    Serial.print("Flow:");          Serial.print(currentFlow);     Serial.print(",");
    Serial.print("TDS:");           Serial.print(currentTDS);      Serial.print(",");
    Serial.print("pH:");            Serial.print(currentPH);       Serial.print(",");
    Serial.print("Moist:");         Serial.print(currentMoisture); Serial.print(","); 
    Serial.print("Server_Status:"); Serial.println(httpCode); 

    http.end();
  } else {
    // Cleaned Serial Print (Offline)
    Serial.print("Level:");         Serial.print(currentDistance); Serial.print(",");
    Serial.print("Flow:");          Serial.print(currentFlow);     Serial.print(",");
    Serial.print("TDS:");           Serial.print(currentTDS);      Serial.print(",");
    Serial.print("pH:");            Serial.print(currentPH);       Serial.print(",");
    Serial.print("Moist:");         Serial.print(currentMoisture); Serial.print(","); 
    Serial.print("Server_Status:"); Serial.println(-2); 
  }
}

void updateDisplay() {
  if (millis() - lastSwitchTime > 2000) {
    lastSwitchTime = millis();
    displayState++;
    if (displayState > 5) displayState = 0; 
    lcd.clear();
    switch(displayState) {
      case 0: lcd.print("Level:"); lcd.setCursor(0,1); lcd.print(currentDistance); lcd.print(" cm"); break;
      case 1: lcd.print("Flow:"); lcd.setCursor(0,1); lcd.print(currentFlow); lcd.print(" L/m"); break;
      case 2: lcd.print("TDS:"); lcd.setCursor(0,1); lcd.print(currentTDS, 0); lcd.print(" ppm"); break;
      case 3: lcd.print("pH:"); lcd.setCursor(0,1); lcd.print(currentPH); break;
      case 4: lcd.print("Status:"); lcd.setCursor(0,1); lcd.print(motorStatus); break;
      case 5: lcd.print("Moist:"); lcd.setCursor(0,1); lcd.print(currentMoisture, 0); lcd.print(" %"); break; 
    }
  }
}
