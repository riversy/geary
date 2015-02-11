/* Copyright 2015 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

public class AccountDialogEditAlternateEmailsPane : AccountDialogPane {
    private class ListItem : Gtk.Label {
        public Geary.RFC822.MailboxAddress mailbox;
        
        public ListItem(Geary.RFC822.MailboxAddress mailbox) {
            this.mailbox = mailbox;
            
            label = "<b>%s</b>".printf(mailbox.address);
            use_markup = true;
            ellipsize = Pango.EllipsizeMode.END;
            xalign = 0.0f;
        }
    }
    
    public string? email { get; private set; default = null; }
    
    public bool changed { get; private set; default = false; }
    
    private Gtk.Label title_label;
    private Gtk.Entry email_entry;
    private Gtk.Button add_button;
    private Gtk.ListBox address_listbox;
    private Gtk.ToolButton delete_button;
    private Gtk.Button cancel_button;
    private Gtk.Button update_button;
    private ListItem? selected_item = null;
    
    private Geary.AccountInformation? account_info = null;
    private Geary.RFC822.MailboxAddress? primary_mailbox = null;
    private Gee.HashSet<string> email_addresses = new Gee.HashSet<string>(
        Geary.String.stri_hash, Geary.String.stri_equal);
    
    public signal void done();
    
    public AccountDialogEditAlternateEmailsPane(Gtk.Stack stack) {
        base (stack);
        
        Gtk.Builder builder = GearyApplication.instance.create_builder("edit_alternate_emails.glade");
        
        // Primary container
        pack_start((Gtk.Widget) builder.get_object("container"));
        
        title_label = (Gtk.Label) builder.get_object("title_label");
        email_entry = (Gtk.Entry) builder.get_object("email_entry");
        add_button = (Gtk.Button) builder.get_object("add_button");
        address_listbox = (Gtk.ListBox) builder.get_object("address_listbox");
        delete_button = (Gtk.ToolButton) builder.get_object("delete_button");
        cancel_button = (Gtk.Button) builder.get_object("cancel_button");
        update_button = (Gtk.Button) builder.get_object("update_button");
        
        email_entry.bind_property("text", add_button, "sensitive", BindingFlags.SYNC_CREATE,
            transform_email_to_sensitive);
        bind_property("changed", update_button, "sensitive", BindingFlags.SYNC_CREATE);
        
        delete_button.sensitive = false;
        
        address_listbox.row_selected.connect(on_row_selected);
        add_button.clicked.connect(on_add_clicked);
        delete_button.clicked.connect(on_delete_clicked);
        cancel_button.clicked.connect(() => { done(); });
        update_button.clicked.connect(on_update_clicked);
    }
    
    private bool transform_email_to_sensitive(Binding binding, Value source, ref Value target) {
        target = Geary.RFC822.MailboxAddress.is_valid_address(email_entry.text);
        
        return true;
    }
    
    public void set_account(Geary.AccountInformation account_info) {
        this.account_info = account_info;
        
        email = account_info.email;
        primary_mailbox = account_info.get_primary_mailbox_address();
        email_addresses.clear();
        changed = false;
        
        // reset/clear widgets
        title_label.label = _("Additional addresses for %s").printf(account_info.email);
        email_entry.text = "";
        
        // clear listbox
        foreach (Gtk.Widget widget in address_listbox.get_children())
            address_listbox.remove(widget);
        
        // Add all email addresses; add_email_address() silently drops the primary address
        foreach (string email_address in account_info.get_all_email_addresses())
            add_email_address(email_address, false);
    }
    
    public override void present() {
        base.present();
        
        // because in a Gtk.Stack, need to do this manually after presenting
        email_entry.grab_focus();
        add_button.has_default = true;
    }
    
    private void add_email_address(string email_address, bool is_change) {
        if (email_addresses.contains(email_address))
            return;
        
        if (!Geary.RFC822.MailboxAddress.is_valid_address(email_address))
            return;
        
        if (Geary.String.stri_equal(email_address, primary_mailbox.address))
            return;
        
        email_addresses.add(email_address);
        
        ListItem item = new ListItem(new Geary.RFC822.MailboxAddress(null, email_address));
        item.show_all();
        address_listbox.add(item);
        
        if (is_change)
            changed = true;
    }
    
    private void remove_email_address(Geary.RFC822.MailboxAddress mailbox) {
        if (!email_addresses.remove(mailbox.address))
            return;
        
        foreach (Gtk.Widget widget in address_listbox.get_children()) {
            Gtk.ListBoxRow row = (Gtk.ListBoxRow) widget;
            ListItem item = (ListItem) row.get_child();
            
            if (item.mailbox.address == mailbox.address) {
                address_listbox.remove(widget);
                
                changed = true;
                
                break;
            }
        }
    }
    
    private void on_row_selected(Gtk.ListBoxRow? row) {
        selected_item = (row != null) ? (ListItem) row.get_child() : null;
        delete_button.sensitive = (selected_item != null);
    }
    
    private void on_add_clicked() {
        add_email_address(email_entry.text, true);
        
        // reset state for next input
        email_entry.text = "";
        email_entry.grab_focus();
        add_button.has_default = true;
    }
    
    private void on_delete_clicked() {
        if (selected_item != null)
            remove_email_address(selected_item.mailbox);
    }
    
    private void on_update_clicked() {
        account_info.replace_alternate_emails(email_addresses);
        
        done();
    }
}

