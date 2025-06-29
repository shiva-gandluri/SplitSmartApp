// src/screens/AuthScreen.js
import React, { useState } from 'react';
import {
  View,
  Text,
  TextInput,
  Button,
  StyleSheet,
  Alert,
  TouchableOpacity,
  ActivityIndicator,
} from 'react-native';
import auth from '@react-native-firebase/auth';

const AuthScreen = ({ navigation }) => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isLogin, setIsLogin] = useState(true);
  const [loading, setLoading] = useState(false);

  const handleAuthentication = async () => {
    if (!email || !password) {
      Alert.alert('Error', 'Please enter both email and password.');
      return;
    }
    setLoading(true);
    try {
      if (isLogin) {
        await auth().signInWithEmailAndPassword(email, password);
        // Alert.alert('Success', 'Logged in successfully!');
        // Navigation to the main app will be handled by the auth state listener in App.js
      } else {
        await auth().createUserWithEmailAndPassword(email, password);
        // Alert.alert('Success', 'User account created & signed in!');
        // Navigation to the main app will be handled by the auth state listener in App.js
      }
    } catch (error) {
      let errorMessage = 'An unknown error occurred.';
      if (error.code === 'auth/email-already-in-use') {
        errorMessage = 'That email address is already in use!';
      } else if (error.code === 'auth/invalid-email') {
        errorMessage = 'That email address is invalid!';
      } else if (error.code === 'auth/user-not-found' || error.code === 'auth/wrong-password') {
        errorMessage = 'Invalid email or password.';
      } else if (error.code === 'auth/weak-password') {
        errorMessage = 'Password is too weak (minimum 6 characters).';
      } else if (error.code === 'auth/network-request-failed') {
        errorMessage = 'Network error. Please check your connection.';
      }
      console.error('Authentication Error:', error.code, error.message);
      Alert.alert('Authentication Failed', errorMessage);
    } finally {
      setLoading(false);
    }
  };

  // const handleGoogleSignIn = async () => {
  //   // To be implemented
  //   Alert.alert('Google Sign-In', 'To be implemented!');
  // };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>{isLogin ? 'Login' : 'Sign Up'}</Text>
      <TextInput
        style={styles.input}
        placeholder="Email"
        value={email}
        onChangeText={setEmail}
        keyboardType="email-address"
        autoCapitalize="none"
        placeholderTextColor="#888"
      />
      <TextInput
        style={styles.input}
        placeholder="Password"
        value={password}
        onChangeText={setPassword}
        secureTextEntry
        placeholderTextColor="#888"
      />
      {loading ? (
        <ActivityIndicator size="large" color="#007bff" style={styles.buttonSpacing} />
      ) : (
        <TouchableOpacity style={[styles.button, styles.buttonSpacing]} onPress={handleAuthentication} disabled={loading}>
          <Text style={styles.buttonText}>{isLogin ? 'Login' : 'Sign Up'}</Text>
        </TouchableOpacity>
      )}
      <TouchableOpacity onPress={() => setIsLogin(!isLogin)} disabled={loading} style={styles.toggleButtonSpacing}>
        <Text style={styles.toggleText}>
          {isLogin ? 'Need an account? Sign Up' : 'Have an account? Login'}
        </Text>
      </TouchableOpacity>
      {/* <TouchableOpacity style={[styles.button, styles.googleButton, styles.buttonSpacing]} onPress={handleGoogleSignIn} disabled={loading}>
        <Text style={styles.buttonText}>Sign in with Google</Text>
      </TouchableOpacity> */}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    padding: 20,
    backgroundColor: '#f5f5f5',
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    marginBottom: 24,
    textAlign: 'center',
    color: '#333',
  },
  input: {
    height: 50,
    borderColor: '#ddd',
    borderWidth: 1,
    marginBottom: 15,
    paddingHorizontal: 15,
    borderRadius: 8,
    backgroundColor: '#fff',
    fontSize: 16,
  },
  button: {
    backgroundColor: '#007bff',
    paddingVertical: 15,
    borderRadius: 8,
    alignItems: 'center',
  },
  buttonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold',
  },
  buttonSpacing: {
    marginTop: 10,
  },
  toggleButtonSpacing: {
    marginTop: 20,
  },
  toggleText: {
    color: '#007bff',
    textAlign: 'center',
    fontSize: 16,
  },
  // googleButton: {
  //   backgroundColor: '#db4437',
  // },
});

export default AuthScreen;
