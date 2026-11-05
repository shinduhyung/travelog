class DiscoveryOption {
  final String text;
  final int points;
  const DiscoveryOption(this.text, this.points);
}

class DiscoveryQuestion {
  final String text, explanation;
  final List<DiscoveryOption> options;
  const DiscoveryQuestion(this.text, this.options, this.explanation);
}

class DiscoveryQuiz {
  final String id, title, description, scoreLabel;
  final List<DiscoveryQuestion> questions;
  const DiscoveryQuiz(
    this.id,
    this.title,
    this.description,
    this.scoreLabel,
    this.questions,
  );
  int score(List<int> answers) {
    if (answers.length != questions.length)
      throw ArgumentError('Complete all questions');
    var points = 0;
    for (var i = 0; i < answers.length; i++) {
      if (answers[i] < 0 || answers[i] >= questions[i].options.length)
        throw ArgumentError('Invalid answer');
      points += questions[i].options[answers[i]].points;
    }
    return (100 * points / (questions.length * 3)).round();
  }
}

const discoveryQuizzes = <String, DiscoveryQuiz>{
  'local': DiscoveryQuiz(
    'local',
    'Tourist vs Local',
    '10 quick choices about your travel style.',
    'Local-style exploration',
    [
      DiscoveryQuestion(
        'You have one free afternoon in a new city.',
        [
          DiscoveryOption("See the famous sights", 0),
          DiscoveryOption("Explore a neighborhood", 3),
          DiscoveryOption("A bit of both", 2),
        ],
        'Both landmark visits and neighborhood exploration are valid ways to travel.',
      ),
      DiscoveryQuestion(
        'How do you get around?',
        [
          DiscoveryOption("Use local transit", 3),
          DiscoveryOption("Take a sightseeing route", 0),
          DiscoveryOption("Mix both routes", 2),
        ],
        'Everyday routes reveal a different side of a city.',
      ),
      DiscoveryQuestion(
        'You revisit a city you enjoyed.',
        [
          DiscoveryOption("Repeat the highlights", 0),
          DiscoveryOption("Try a new neighborhood", 2),
          DiscoveryOption("Familiar spots, new streets", 3),
        ],
        'Familiarity grows through repeated, ordinary experiences.',
      ),
      DiscoveryQuestion(
        'What do you ask a resident?',
        [
          DiscoveryOption("Best photo spot?", 0),
          DiscoveryOption("Your usual weekend spot?", 3),
          DiscoveryOption("Where would you take a friend?", 2),
        ],
        'Different questions lead to different kinds of experiences.',
      ),
      DiscoveryQuestion(
        'Your plans change unexpectedly.',
        [
          DiscoveryOption("Explore nearby streets", 3),
          DiscoveryOption("Find another attraction", 0),
          DiscoveryOption("One stop, then wander", 2),
        ],
        'This measures preferences, not travel competence.',
      ),
      DiscoveryQuestion(
        'What makes a city memorable to you?',
        [
          DiscoveryOption("Iconic sights", 0),
          DiscoveryOption("Sights and daily life", 2),
          DiscoveryOption("Streets, routines, people", 3),
        ],
        'A blended style is just as valid as either end of the scale.',
      ),
      DiscoveryQuestion('Where would you eat on a free evening?', [DiscoveryOption('A famous must-try spot', 0), DiscoveryOption('A busy neighborhood place', 3), DiscoveryOption('Whichever looks good nearby', 2)], 'Dining choices describe your style, not a better way to travel.'),
      DiscoveryQuestion('You have already seen the main sights. What next?', [DiscoveryOption('Another famous attraction', 0), DiscoveryOption('Wander familiar streets', 3), DiscoveryOption('One sight, then wander', 2)], 'The question separates landmark-focused plans from everyday exploration.'),
      DiscoveryQuestion('How would you spend a whole week in one city?', [DiscoveryOption('Tick off the major sights', 0), DiscoveryOption('Settle into a daily routine', 3), DiscoveryOption('Mix sights and slow days', 2)], 'Both structured sightseeing and a slower routine are valid preferences.'),
      DiscoveryQuestion('What is your favorite travel memory?', [DiscoveryOption('Finally seeing an icon', 0), DiscoveryOption('A small local encounter', 3), DiscoveryOption('A little of both', 2)], 'Travel memories reflect what you value in a visit.'),
    ],
  ),
  'survival': DiscoveryQuiz(
    'survival',
    'Travel Survival',
    '20 travel curveballs. How would you handle them?',
    'Travel readiness',
    [
      DiscoveryQuestion(
        'Your phone loses its connection in an unfamiliar city.',
        [
          DiscoveryOption("Offline map ready", 3),
          DiscoveryOption("Online links only", 0),
          DiscoveryOption("Route screenshot saved", 2),
        ],
        'Offline information provides another way to find your destination.',
      ),
      DiscoveryQuestion(
        'A transport delay disrupts your planned connection.',
        [
          DiscoveryOption("Stick to the old plan", 0),
          DiscoveryOption("Check times and alternatives", 3),
          DiscoveryOption("Ask, but skip the timetable", 1),
        ],
        'Updated information and a backup plan make disruption easier to handle.',
      ),
      DiscoveryQuestion(
        'Your usual payment method is temporarily unavailable.',
        [
          DiscoveryOption("Backup payment ready", 3),
          DiscoveryOption("Only one payment method", 0),
          DiscoveryOption("Contact support, no backup", 1),
        ],
        'This scenario rewards having a practical fallback.',
      ),
      DiscoveryQuestion(
        'You need to explain a destination in a language you do not speak.',
        [
          DiscoveryOption("Say it louder", 0),
          DiscoveryOption("Show the address, translate", 3),
          DiscoveryOption("Use gestures, guess the address", 1),
        ],
        'Written details reduce ambiguity in an unfamiliar language.',
      ),
      DiscoveryQuestion(
        'Your main bag arrives later than you do.',
        [
          DiscoveryOption("Everything is in that bag", 0),
          DiscoveryOption("Essentials in my carry-on", 3),
          DiscoveryOption("Buy replacements later", 1),
        ],
        'The score reflects preparation for this fictional disruption.',
      ),
      DiscoveryQuestion(
        'An important reservation cannot be found immediately.',
        [
          DiscoveryOption("Confirmation saved offline", 3),
          DiscoveryOption("Find it online later", 0),
          DiscoveryOption("Only remember the company", 1),
        ],
        'Accessible confirmations save time when a plan needs checking.',
      ),
      DiscoveryQuestion(
        "Your arrival crosses midnight in the destination time zone.",
        [
          DiscoveryOption("Use the departure date", 0),
          DiscoveryOption("Check the local arrival date", 3),
          DiscoveryOption("Check after landing", 1),
        ],
        "The local arrival date is the one your destination reservation needs.",
      ),
      DiscoveryQuestion(
        "You expect to arrive after the usual check-in window.",
        [
          DiscoveryOption("Confirm late arrival", 3),
          DiscoveryOption("Assume 24-hour check-in", 0),
          DiscoveryOption("Save only the address", 1),
        ],
        "Confirming the arrangement avoids a surprise at the door.",
      ),
      DiscoveryQuestion(
        "A tour meeting point is listed as a large public square.",
        [
          DiscoveryOption("Wait at any corner", 0),
          DiscoveryOption("Save the exact meeting spot", 3),
          DiscoveryOption("Ask when I get there", 1),
        ],
        "A precise meeting point is more useful than a broad place name.",
      ),
      DiscoveryQuestion(
        "Rain changes your outdoor plans for the afternoon.",
        [
          DiscoveryOption("Have an indoor backup", 3),
          DiscoveryOption("Cancel the whole day", 0),
          DiscoveryOption("Find a backup after it starts", 1),
        ],
        "A flexible alternative makes the day easier to adapt.",
      ),
      DiscoveryQuestion(
        "Your phone battery is nearly empty before the return journey.",
        [
          DiscoveryOption("Hope the battery lasts", 0),
          DiscoveryOption("Save the route, find a charger", 3),
          DiscoveryOption("Only remember the station", 1),
        ],
        "Keeping the return details accessible gives you a practical fallback.",
      ),
      DiscoveryQuestion(
        "Your train platform changes shortly before departure.",
        [
          DiscoveryOption("Follow the old screenshot", 0),
          DiscoveryOption("Check the live board", 3),
          DiscoveryOption("Follow the crowd", 1),
        ],
        "Current service information is more useful than an old platform assignment.",
      ),
      DiscoveryQuestion(
        "Your ticket uses a 24-hour clock: departure is at 18:20.",
        [
          DiscoveryOption("8:20 in the morning", 0),
          DiscoveryOption("6:20 in the evening", 3),
          DiscoveryOption("Guess at the station", 1),
        ],
        "18:20 is 6:20 p.m.",
      ),
      DiscoveryQuestion(
        "There are two stations with similar names in the same city.",
        [
          DiscoveryOption("Check the station on my ticket", 3),
          DiscoveryOption("Use the first search result", 0),
          DiscoveryOption("Only remember the city", 1),
        ],
        "The full station identity avoids a wrong departure point.",
      ),
      DiscoveryQuestion(
        "Your accommodation has an entrance code in a message.",
        [
          DiscoveryOption("Find the message at the door", 0),
          DiscoveryOption("Save entry details offline", 3),
          DiscoveryOption("Only remember the building", 1),
        ],
        "Accessible arrival instructions make check-in smoother.",
      ),
      DiscoveryQuestion(
        "You have one afternoon and a list of five places far apart.",
        [
          DiscoveryOption("Group nearby stops", 3),
          DiscoveryOption("Ignore travel time", 0),
          DiscoveryOption("Pick an order without a map", 1),
        ],
        "Grouping nearby stops reduces unnecessary backtracking.",
      ),
      DiscoveryQuestion(
        "The attraction you planned for today has a weekly closure.",
        [
          DiscoveryOption("Check opening days first", 3),
          DiscoveryOption("Go without checking", 0),
          DiscoveryOption("Check after paying for transit", 1),
        ],
        "The opening day matters as much as the opening hour.",
      ),
      DiscoveryQuestion(
        "Your train ticket is saved only in one email account.",
        [
          DiscoveryOption("Save the ticket and reference", 3),
          DiscoveryOption("Remember the email subject", 1),
          DiscoveryOption("Delete the email", 0),
        ],
        "An accessible copy gives you another way to retrieve the booking.",
      ),
      DiscoveryQuestion(
        "A walking route is much longer than the straight-line distance.",
        [
          DiscoveryOption("Check the route and travel time", 3),
          DiscoveryOption("Use straight-line distance", 0),
          DiscoveryOption("Assume all shortcuts work", 1),
        ],
        "Actual routes include the crossings and entrances you need.",
      ),
      DiscoveryQuestion(
        "Your group splits up before a busy afternoon.",
        [
          DiscoveryOption("Set a meeting spot and time", 3),
          DiscoveryOption("Find each other somehow", 0),
          DiscoveryOption("Name an area, no time", 1),
        ],
        "A specific meeting arrangement is easier to follow.",
      ),
    ],
  ),
  'savvy': DiscoveryQuiz(
    'savvy',
    'Overpaying Test',
    'Spot the hidden costs and find the better deal.',
    'Price-checking skills',
    [
      DiscoveryQuestion(
        'Two identical tickets cost 20 and 25 units. The second includes a gift you do not want.',
        [
          DiscoveryOption("25, for the free gift", 0),
          DiscoveryOption("20, same conditions", 3),
          DiscoveryOption("Take the first offer", 1),
        ],
        'Compare the total cost and the conditions you actually need.',
      ),
      DiscoveryQuestion(
        'A room is advertised at 80 units, with 15 in required fees. Another includes everything for 90.',
        [
          DiscoveryOption("80 must be cheaper", 0),
          DiscoveryOption("Compare 95 vs 90", 3),
          DiscoveryOption("Ignore the extra fees", 0),
        ],
        'The total is 95 versus 90 in this fictional example.',
      ),
      DiscoveryQuestion(
        'A seller says the price is only available right now.',
        [
          DiscoveryOption("Buy before time runs out", 0),
          DiscoveryOption("Compare the offer first", 3),
          DiscoveryOption("Ask once, then buy", 1),
        ],
        'Urgency alone does not establish value.',
      ),
      DiscoveryQuestion(
        'An offer shows 100 in one currency and 100 in another.',
        [
          DiscoveryOption("Treat both prices as equal", 0),
          DiscoveryOption("Check the currency first", 3),
          DiscoveryOption("Pick the familiar symbol", 1),
        ],
        'The fictional offers cannot be compared without their units.',
      ),
      DiscoveryQuestion(
        'A cheap booking has different cancellation terms.',
        [
          DiscoveryOption("Skip the terms", 0),
          DiscoveryOption("Check terms against my plans", 3),
          DiscoveryOption("Buy the priciest option", 1),
        ],
        'A useful comparison includes conditions, not just the headline price.',
      ),
      DiscoveryQuestion(
        'A bundle costs 60 units. The two items you actually need cost 20 each separately.',
        [
          DiscoveryOption("More items means better value", 0),
          DiscoveryOption("Compare 40 vs 60", 3),
          DiscoveryOption("Skip the price breakdown", 0),
        ],
        'More items do not automatically mean a better fit for your needs.',
      ),
      DiscoveryQuestion(
        "A fictional menu adds a 25% service fee to a 40-unit meal. Another meal costs 48 including everything.",
        [
          DiscoveryOption("40 must be cheaper", 0),
          DiscoveryOption("Compare 50 vs 48", 3),
          DiscoveryOption("Choose by the photos", 1),
        ],
        "40 plus 25% is 50, so compare that total with 48.",
      ),
      DiscoveryQuestion(
        "Three tickets cost 15 units each. A bundle of the same three costs 50 and adds nothing else.",
        [
          DiscoveryOption("Bundles always save money", 0),
          DiscoveryOption("45 separately, save 5", 3),
          DiscoveryOption("Buy without adding it up", 1),
        ],
        "Three times 15 is 45; the bundle is 5 more.",
      ),
      DiscoveryQuestion(
        "A fictional ride quote is 5 units plus 2 per kilometer for 4 kilometers. The alternative is a flat 18.",
        [
          DiscoveryOption("Compare 13 vs 18", 3),
          DiscoveryOption("Flat fares are always cheaper", 0),
          DiscoveryOption("Ignore the distance charge", 1),
        ],
        "5 plus 2 times 4 is 13 in this example.",
      ),
      DiscoveryQuestion(
        "One bottle costs 5 units. A pack of three identical bottles costs 12, and you need three.",
        [
          DiscoveryOption("Buy three single bottles", 0),
          DiscoveryOption("Compare 4 vs 5 per bottle", 3),
          DiscoveryOption("Choose by the price label", 1),
        ],
        "The pack is 4 per bottle; three singles cost 15.",
      ),
      DiscoveryQuestion(
        "A listing says 80% off, but you cannot find a previous selling price.",
        [
          DiscoveryOption("Discount means a good deal", 0),
          DiscoveryOption("Compare equivalent totals", 3),
          DiscoveryOption("Trust the high original price", 1),
        ],
        "The current total is comparable; an unexplained reference price is not.",
      ),
      DiscoveryQuestion(
        "A booking total changes after an optional extra is selected automatically.",
        [
          DiscoveryOption("Remove unwanted extras", 3),
          DiscoveryOption("Pay the new total unchecked", 0),
          DiscoveryOption("Check only the headline price", 1),
        ],
        "Review the final basket rather than relying on the original headline.",
      ),
      DiscoveryQuestion(
        "A 30-unit product has a 10% discount and a mandatory 4-unit fee.",
        [
          DiscoveryOption("27 total", 0),
          DiscoveryOption("31 total", 3),
          DiscoveryOption("24 total", 1),
        ],
        "30 minus 3 plus 4 is 31.",
      ),
      DiscoveryQuestion(
        "Two identical rooms cost 70 plus 12 in fees, or 85 with no extra fees.",
        [
          DiscoveryOption("Compare 82 vs 85", 3),
          DiscoveryOption("No fee means cheaper", 0),
          DiscoveryOption("Treat 70 and 85 as final", 1),
        ],
        "The first total is 82; the second is 85.",
      ),
      DiscoveryQuestion(
        "A 40-unit item is offered as buy one, get the second at half price. You need two.",
        [
          DiscoveryOption("60 for the pair", 3),
          DiscoveryOption("40 for the pair", 0),
          DiscoveryOption("80 for the pair", 1),
        ],
        "The second item costs 20, making the pair 60.",
      ),
      DiscoveryQuestion(
        "A three-day pass costs 36 units. Individual days cost 10 each, and you only need two days.",
        [
          DiscoveryOption("Buy the longer pass", 0),
          DiscoveryOption("Compare 20 vs 36", 3),
          DiscoveryOption("Passes always save money", 1),
        ],
        "Only the days you plan to use belong in the comparison.",
      ),
      DiscoveryQuestion(
        "A seller describes an item as premium but provides no extra specifications.",
        [
          DiscoveryOption("Compare specs and terms", 3),
          DiscoveryOption("Pay extra for premium", 0),
          DiscoveryOption("Judge by package size", 1),
        ],
        "A label alone does not describe the difference you receive.",
      ),
      DiscoveryQuestion(
        "A 50-unit booking includes two people. A 30-unit quote is per person.",
        [
          DiscoveryOption("Compare 50 vs 60 for two", 3),
          DiscoveryOption("30 is the group total", 0),
          DiscoveryOption("Ignore the group size", 1),
        ],
        "The same group costs 50 versus two times 30.",
      ),
      DiscoveryQuestion(
        "A return trip costs 18 units. Two one-way tickets cost 8 each with the same conditions.",
        [
          DiscoveryOption("Compare 18 vs 16", 3),
          DiscoveryOption("Return tickets are cheaper", 0),
          DiscoveryOption("Compare against one single", 1),
        ],
        "Two times 8 is 16.",
      ),
      DiscoveryQuestion(
        "The cheapest visible offer is for a smaller size than the one you need.",
        [
          DiscoveryOption("Compare same-size final totals", 3),
          DiscoveryOption("Pick the lowest number", 0),
          DiscoveryOption("All sizes cost the same", 1),
        ],
        "Comparable offers cover the same size and conditions.",
      ),
    ],
  ),
};
