# ConciergeX

ConciergeX is a smart restaurant booking assistant that helps users find and book restaurants based on their preferences, dietary requirements, and group dynamics.

## Features

- Smart restaurant search with natural language processing
- Group management and preferences
- Location-based restaurant recommendations
- Dietary requirements and preferences management
- Real-time availability checking
- Interactive map view of restaurants

## Prerequisites

Before you begin, ensure you have the following installed:
- Flutter SDK (version 3.6.0 or higher)
- Dart SDK
- Git
- A code editor (VS Code, Android Studio, etc.)
- iOS/Android development setup for mobile deployment

## Setup Instructions

1. **Clone the Repository**
   ```bash
   git clone https://github.com/zarathomas2107/ConciergeX.git
   cd ConciergeX
   ```

2. **Environment Setup**
   ```bash
   # Copy the environment template
   cp .env.example .env
   ```
   Open `.env` and fill in your API keys:
   - `SUPABASE_URL`: Your Supabase project URL
   - `SUPABASE_ANON_KEY`: Your Supabase anonymous key
   - `SUPABASE_SERVICE_ROLE_KEY`: Your Supabase service role key
   - `GOOGLE_API_KEY`: Google Maps API key
   - `OPENAI_API_KEY`: OpenAI API key
   - `MAPBOX_ACCESS_TOKEN`: Mapbox access token

3. **Install Dependencies**
   ```bash
   flutter pub get
   ```

4. **Run the App**
   ```bash
   # For development
   flutter run

   # For production build
   flutter build ios  # For iOS
   flutter build apk  # For Android
   ```

## Project Structure

- `lib/screens/`: Contains all the screen widgets
- `lib/widgets/`: Reusable widget components
- `lib/models/`: Data models
- `lib/services/`: Business logic and API services
- `assets/`: Static assets like images and icons

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## Troubleshooting

If you encounter any issues:

1. Ensure all API keys in `.env` are valid and have the necessary permissions
2. Check Flutter version compatibility: `flutter --version`
3. Clean and rebuild the project:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

## Support

For support, please open an issue in the GitHub repository or contact the development team.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
