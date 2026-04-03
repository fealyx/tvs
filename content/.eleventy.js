const { DateTime } = require("luxon");

module.exports = function(eleventyConfig) {
  // Copy assets through as-is
  eleventyConfig.addPassthroughCopy("src/assets");
  eleventyConfig.addPassthroughCopy("src/*.png");
  eleventyConfig.addPassthroughCopy("src/*.jpg");
  eleventyConfig.addPassthroughCopy("src/*.gif");
  eleventyConfig.addPassthroughCopy("src/tools/**/*.md");

  // Create collections for content organization
  eleventyConfig.addCollection("guides", function(collection) {
    return collection
      .getFilteredByGlob("src/guides/**/*.md")
      .sort((a, b) => new Date(b.date) - new Date(a.date));
  });

  eleventyConfig.addCollection("tutorials", function(collection) {
    return collection
      .getFilteredByGlob("src/tutorials/**/*.md")
      .sort((a, b) => new Date(b.date) - new Date(a.date));
  });

  eleventyConfig.addCollection("discoveries", function(collection) {
    return collection
      .getFilteredByGlob("src/discoveries/**/*.md")
      .sort((a, b) => new Date(b.date) - new Date(a.date));
  });

  eleventyConfig.addCollection("byCategory", function(collection) {
    let categories = {};
    collection.getAll().forEach(item => {
      if (!item.data.draft && item.data.category) {
        let category = item.data.category;
        if (!categories[category]) {
          categories[category] = [];
        }
        categories[category].push(item);
      }
    });
    return categories;
  });

  // Filters
  eleventyConfig.addFilter("readableDate", dateObj => {
    return DateTime.fromJSDate(dateObj, { zone: 'utc' }).toFormat('LLLL d, yyyy');
  });

  eleventyConfig.addFilter("htmlDateString", dateObj => {
    return DateTime.fromJSDate(dateObj, { zone: 'utc' }).toISO();
  });

  eleventyConfig.addFilter("head", (array, n) => {
    if(!Array.isArray(array) || array.length === 0) {
      return [];
    }
    if(n < 0) {
      return array.slice(n);
    }
    return array.slice(0, n);
  });

  return {
    dir: {
      input: "src",
      output: "_site",
      layouts: "_includes/layouts"
    },
    markdownTemplateEngine: "njk",
    htmlTemplateEngine: "njk",
    templateFormats: ["md", "njk", "html", "json"]
  };
};
