def test_imports():
    try:
        from search_service.agents.venue_agent import VenueAgent
        print("✅ Successfully imported VenueAgent")
    except ImportError as e:
        print(f"❌ Failed to import VenueAgent: {e}")
        assert False, f"Import failed: {e}"

if __name__ == "__main__":
    test_imports() 